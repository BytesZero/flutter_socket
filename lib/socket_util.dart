import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:longtao/common/constants.dart';
import 'package:longtao/common/store_util.dart';
import 'package:longtao/common/util.dart';
import 'package:longtao/entities/socket_response.dart';
import 'package:longtao/main.dart';
import 'package:longtao/models/drama_dm_model.dart';
import 'package:longtao/models/drama_game_model.dart';
import 'package:longtao/models/matching_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert' as convert;

enum RoomCmd {
  appDeclare,
  appPing,
  reconnect,
  joinRoom,
  chooseRole,
  readyGame,
  startGame,
  getRoleDatas,
  readyToNext,
  nextStage,
  useProp,
  getClue,
  openClue,
  vote,
  dmJoin,
  dmData,
  dmBegin,
  dmOperate,
  dmNext,
  dmExit,
}

class SocketUtil {
  // 工厂模式
  factory SocketUtil() => _getInstance()!;
  static SocketUtil get instance => _getInstance()!;
  static SocketUtil? _instance;
  bool _connecting = false;
  bool _ping = false;
  bool connected = false;
  IOWebSocketChannel? _channel;
  Timer? _timer;

  SocketUtil._internal() {
    // 初始化
  }

  get msg => null;

  static SocketUtil? _getInstance() {
    if (_instance == null) {
      _instance = new SocketUtil._internal();
    }
    return _instance;
  }

  void connect(MyCallback callback) {
    if (_connecting) {
      return;
    }
    if (connected) {
      callback(true);
      return;
    }
    _connecting = true;
    final port = bool.fromEnvironment('dart.vm.product') ? '6002' : '6001';
    _channel = IOWebSocketChannel.connect('wss://dreama.cn:$port');
    _channel?.stream.listen((event) async {
      debugPrint('WebSocket消息：$event');
      Map<String, dynamic> json = convert.jsonDecode(event);
      if (json['cmd'] == 'connection_successful') {
        _connecting = false;
        connected = true;
        int userId = await StoreUtil.getUserId();
        String token = await StoreUtil.getLoginToken();
        send(RoomCmd.appDeclare, {'user_id': userId});
        if (_timer != null) {
          _timer!.cancel();
          _timer = null;
        }
        _timer = Timer.periodic(Duration(seconds: 30), (timer) {
          if (_ping) {
            reconnect();
          } else {
            _ping = true;
            Map<String, dynamic> params = {
              'user_id': userId,
              'token': token,
              'time_stamp': DateTime.now().millisecondsSinceEpoch
            };
            send(RoomCmd.appPing, params);
          }
        });
        callback(true);
        return;
      }
      _dispatchMessage(json);
    }, onError: _onError, onDone: _onDone);
  }

  void send(RoomCmd cmd, Map<String, dynamic> params) {
    if (!connected) {
      connect((res) {
        if (res) {
          _sendMsg(cmd, params);
        }
      });
    } else {
      _sendMsg(cmd, params);
    }
  }

  void reconnect() {
    BuildContext context = navigatorKey.currentState!.overlay!.context;
    bool matching = Provider.of<MatchingModel>(context, listen: false).status !=
        MatchingStatus.none;
    DramaGameModel gameModel =
        Provider.of<DramaGameModel>(context, listen: false);
    bool dming = Provider.of<DramaDMModel>(context, listen: false).dming;
    if (!matching && !gameModel.playing && !dming) {
      return;
    }

    connected = false;
    connect((res) async {
      if (res && !matching && !dming && gameModel.choseRole != null) {
        gameModel.reconnect();
      }
    });
  }

  void close() {
    connected = false;
    if (_channel != null) {
      _channel!.sink.close();
    }
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  // 收到Error时触发
  _onError(err) {
    // cancelOnError：遇到第一个Error时是否取消订阅，默认为false。cancelOnError 为true时，出现onError时，onDone将不会回调
    debugPrint('WebSocket错误：${convert.jsonEncode(err)}');
    _connecting = false;
  }

  // 结束时触发
  _onDone() {
    debugPrint('WebSocket结束');
    _connecting = false;
    reconnect();
  }

  void _sendMsg(RoomCmd cmd, Map<String, dynamic> params) async {
    final Map<String, dynamic> data = {'cmd': _cmdOfEnum(cmd)};
    if (cmd == RoomCmd.joinRoom) {
      data['token'] = await StoreUtil.getLoginToken();
    }
    if (params.isNotEmpty) {
      data.addAll(params);
    }
    String json = convert.jsonEncode(data);
    debugPrint('WebSocket参数：$json');
    _channel!.sink.add(json);
  }

  String _cmdOfEnum(RoomCmd cmd) {
    switch (cmd) {
      case RoomCmd.appDeclare:
        return 'app_declare';
      case RoomCmd.appPing:
        return 'app_ping';
      case RoomCmd.reconnect:
        return 'app_reconnection';
      case RoomCmd.joinRoom:
        return 'to_join';
      case RoomCmd.chooseRole:
        return 'select_role';
      case RoomCmd.readyGame:
        return 'to_prepare';
      case RoomCmd.startGame:
        return 'to_begin';
      case RoomCmd.getRoleDatas:
        return 'get_role_data';
      case RoomCmd.readyToNext:
        return 'to_prepare_next';
      case RoomCmd.nextStage:
        return 'to_next';
      case RoomCmd.useProp:
        return 'to_prop';
      case RoomCmd.getClue:
        return 'get_proof';
      case RoomCmd.openClue:
        return 'to_open_proof';
      case RoomCmd.vote:
        return 'to_vote';
      case RoomCmd.dmJoin:
        return 'app_dm_join';
      case RoomCmd.dmData:
        return 'app_dm_data';
      case RoomCmd.dmBegin:
        return 'app_dm_begin';
      case RoomCmd.dmOperate:
        return 'app_dm_operate';
      case RoomCmd.dmNext:
        return 'app_dm_next';
      case RoomCmd.dmExit:
        return 'app_dm_exit';
    }
  }

  void _dispatchMessage(Map<String, dynamic> msg) {
    String cmd = msg['cmd'];
    if (cmd == 'app_declare_success') {
      return;
    } else if (cmd == 'app_pong') {
      _ping = false;
      return;
    }

    BuildContext context = navigatorKey.currentState!.overlay!.context;
    if (cmd == 'join_team_success' || cmd == 'match_success') {
      MatchingModel matchModel =
          Provider.of<MatchingModel>(context, listen: false);
      matchModel.getMatching(matchModel.match!.id, (res) {},
          showLoading: false);
      return;
    }

    SocketResponse res = SocketResponse.fromJson(msg);
    DramaGameModel gameModel =
        Provider.of<DramaGameModel>(context, listen: false);
    DramaDMModel dmModel = Provider.of<DramaDMModel>(context, listen: false);
    if (res.code == 400) {
      EasyLoading.showToast(res.cmd);
    } else if (res.cmd == 'please_login') {
      // 需要重新登录
      Util.needLogin();
    } else if (res.cmd == 'to_prepare_success') {
      // 准备开始游戏
      if (dmModel.dming) {
        dmModel.saveReadyStart(res.data['account']);
      } else {
        gameModel.saveReadyStart(res.data['account']);
      }
    } else {
      List<String> dmCmds = [
        'dm_join_success',
        'dm_begin_success',
        'dm_data_success',
        'dm_next_success',
        'user_prepare_success',
        'dm_drama_finish'
      ];
      if (dmCmds.contains(res.cmd)) {
        dmModel.operateMessage(res);
      } else {
        gameModel.operateMessage(res);
      }
    }
  }
}
