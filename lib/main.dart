import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Messaging',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(title: 'Cloud Messaging'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class FCMService {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  // Local notifications for popups
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize({required void Function(RemoteMessage) onData}) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await localNotifications.initialize(settings: initSettings);

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      onData(message);
      // Manually show popup with message
      _showLocalNotification(message);  
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onData(message);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      onData(initialMessage);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.high,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<String?> getToken() {
    return messaging.getToken();
  }
}

class _HomePageState extends State<HomePage> {
  final FCMService _fcmService = FCMService();
  String statusText = 'Waiting for a cloud message';
  String bodyText = 'Waiting for cloud message body';
  String imagePath = 'assets/images/default.jpg';
  

  @override
  void initState() {
    super.initState();
    _initFCM();
    _fcmService.initialize(onData: (message) {
      setState(() {
        statusText = message.notification?.title ?? 'Payload received';
        bodyText = message.notification?.body ?? '';  
        imagePath = 'assets/images/${message.data['asset'] ?? 'default'}.jpg';
      });
    });   
  }

  Future<void> _initFCM() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM token: $token');
  }

  @override                                      
  Widget build(BuildContext context) {           
    return Scaffold(                             
      appBar: AppBar(title: Text(widget.title)), 
      body: Center(                              
        child: Column(                           
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath),              
            Text(statusText),   
            Text(bodyText),                 
          ],
        ),
      ),
    );
  }
}


