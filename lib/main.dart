import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/dashboard_screen.dart';
import 'screens/monthly_status_screen.dart';
import 'screens/tax_screen.dart';
import 'services/monthly_scheduler_service.dart';
import 'services/local_notification_service.dart';
import 'services/monthly_retry_manager.dart';


Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();


  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://ifisogduvyerncltqulc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlmaXNvZ2R1dnllcm5jbHRxdWxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MTUwMzEsImV4cCI6MjA3MDk5MTAzMX0.Z6m5wQjcllZD_76GGv9thzjEmjMXH1y6IZUaZ2r1toI', 
  );

  // Local notifications (used for retry prompt)
  await LocalNotificationService().initialize(
    onNotificationResponse: (payload) async {
      await MonthlyRetryManager.handleNotificationPayload(payload);
    },
  );

  // Initialize WorkManager for the manual monthly processor task.
  await MonthlySchedulerService.initialize();
  // Monthly balance fetch remains manual via the play button.
  // await MonthlySchedulerService.scheduleMonthlyTask();


  runApp(const MyApp());

  // Handle pending retry if app was opened after notification.
  await MonthlyRetryManager.maybeRetryFromAppLaunch();
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bank Balance Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainRootScreen(),
    );
  }
}

class MainRootScreen extends StatefulWidget {
  const MainRootScreen({super.key});

  @override
  State<MainRootScreen> createState() => _MainRootScreenState();
}

class _MainRootScreenState extends State<MainRootScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const DashboardScreen(),
    const MonthlyStatusScreen(),
    const TaxScreen(),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Manual',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Monthly',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Tax',
          ),
        ],
      ),

    );
  }
}
