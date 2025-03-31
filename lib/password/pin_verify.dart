// VerifyPinScreen.dart
import 'package:flutter/material.dart';
import 'package:gst_invoice/gst_invoice.dart';
import 'dart:io';
import '../color.dart';
import '../database/sharedprefhelper.dart';

class VerifyPinScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const VerifyPinScreen({super.key, this.onSuccess});

  @override
  State<VerifyPinScreen> createState() => _VerifyPinScreenState();
}

class _VerifyPinScreenState extends State<VerifyPinScreen>
    with TickerProviderStateMixin {
  late AnimationController animationController;
  String enteredPin = '';
  bool showErrorMessage = false;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin(BuildContext context, String pin) async {
    String? savedPin = await SharedPrefHelper.get(prefKey: PrefKey.pin);
    if (savedPin == enteredPin) {
      setState(() {
        showErrorMessage = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => GstInvoice()),
      );
    } else {
      setState(() {
        showErrorMessage = true;
        enteredPin = '';
      });
    }
  }

  Future<bool> showExitPopup() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Exit App',
          style: TextStyle(color: Theme.of(context).colorScheme.background),
        ),
        content: Text(
          'Do you want to exit the app?',
          style: TextStyle(color: Theme.of(context).colorScheme.background),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No', style: TextStyle(color: Theme.of(context).colorScheme.background)),
          ),
          TextButton(
            onPressed: () => exit(0),
            child: Text('Yes', style: TextStyle(color: Theme.of(context).colorScheme.background)),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: showExitPopup,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 130,
                width: 125,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    fit: BoxFit.fill,
                    image: AssetImage('assets/images/logo.png'),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                "GST Invoice",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.background,
                ),
              ),
              SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 100.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    4,
                        (index) => AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: enteredPin.length > index
                            ? Theme.of(context).colorScheme.background
                            : Colors.white,
                        border: Border.all(color: Theme.of(context).colorScheme.background, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              if (showErrorMessage)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    "Incorrect PIN. Try again.",
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              Spacer(),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 35),
                child: GridView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) return SizedBox.shrink();
                    if (index == 11) {
                      return InkWell(
                        onTap: () {
                          if (enteredPin.isNotEmpty) {
                            setState(() {
                              enteredPin = enteredPin.substring(
                                  0, enteredPin.length - 1);
                            });
                          }
                        },
                        child: Icon(Icons.backspace_outlined, size: 28),
                      );
                    }
                    final digit = index == 10 ? '0' : (index + 1).toString();
                    return InkWell(
                      onTap: () {
                        if (enteredPin.length < 4) {
                          setState(() {
                            enteredPin += digit;
                            if (enteredPin.length == 4) {
                              _verifyPin(context, enteredPin);
                            }
                          });
                        }
                      },
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.background,
                        child: Text(
                          digit,
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}