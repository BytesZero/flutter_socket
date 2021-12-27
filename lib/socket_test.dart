import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

WebSocket? ws;
IOWebSocketChannel? iws;

void main(List<String> args) async {
  // connect();
  // 打印提示
  stdout.write('请输入(\'q\'退出):');
  // 监听输入
  stdin.listen((event) async {
    String input = utf8.decode(event);
    if (input.isNotEmpty) {
      if (input == 'q\n') {
        ws?.close();
        iws?.sink.close();
        stdout.addError('关闭 WebSocket');
        return;
      } else if (input == 'ws\n') {
        stdout.writeln('WebSocket 连中');
        connect();
        return;
      } else if (input == 'r\n') {
        ws?.close();
        stdout.writeln('关闭 WebSocket');
        await Future.delayed(Duration(seconds: 3));
        stdout.writeln('WebSocket 重连中');
        connect();
        return;
      } else if (input == 'iws\n') {
        stdout.writeln('IoWebSocket 连中');
        connectIo();
        return;
      } else if (input == 'ri\n') {
        iws?.sink.close();
        stdout.writeln('关闭 IoWebSocket');
        await Future.delayed(Duration(seconds: 3));
        stdout.writeln('IoWebSocket 重连中');
        connectIo();
        return;
      }
      if (ws != null) {
        ws?.add(input);
      } else {
        iws?.sink.add(input);
      }
    }
  });
}

Future<void> connect() async {
  // 连接 WebSocket
  // var ws = await WebSocket.connect('wss://socket.idcd.com:1443');
  ws = await WebSocket.connect('wss://dreama.cn:6001');
  // 监听服务端返回的消息
  ws?.listen((event) {
    stdout.write('服务端收到$event');
    // 打印提示
    stdout.write('\n请输入(\'q\'退出):');
  });
}

Future<void> connectIo() async {
  // 连接 WebSocket
  // var ws = await WebSocket.connect('wss://socket.idcd.com:1443');
  try {
    iws = IOWebSocketChannel.connect('wss://dreama.cn:6001');
  } catch (e) {
    print(e.toString());
  }
  // 监听服务端返回的消息
  iws?.stream.listen((event) {
    stdout.write('服务端收到$event');
    // 打印提示
    stdout.write('\n请输入(\'q\'退出):');
  });
  // 打印提示
  stdout.write('请输入(\'q\'退出):');
}
