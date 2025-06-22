import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Message {
  final bool isUser;
  final String message;
  final DateTime date;
  final bool isLoading;

  Message({required this.isUser, required this.message, required this.date, this.isLoading = false});
}

class Messages extends StatelessWidget {
  final bool isUser;
  final String message;
  final DateTime date;
  final bool isLoading;

  const Messages({
    super.key,
    required this.isUser,
    required this.message,
    required this.date,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Format date to "HH:MM"
    final formattedDate = DateFormat('HH:mm').format(date);

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(15),
                margin: EdgeInsets.only(
                  top: 4,
                  bottom: 4,
                  left: isUser ? 100 : 10,
                  right: isUser ? 10 : 100,
                ),
                decoration: BoxDecoration(
                  color: isUser ? Colors.blue : Colors.grey.shade300,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                    bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                  ),
                ),
                // child: isLoading
                //     ? const LoadingDots()
                //     : Text(
                //   message,
                //   style: TextStyle(fontSize: 16, color: isUser ? Colors.white : Colors.black),
                // ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    isLoading
                        ? const LoadingDots()
                        : Text(
                      message,
                      style: TextStyle(fontSize: 16, color: isUser ? Colors.white : Colors.black),
                    ),
                    Positioned(
                      bottom: -6,
                      left: isUser ? null : -10,
                      right: isUser ? -10 : null,
                      child: CustomPaint(
                        painter: BubbleTailPainter(isUser: isUser),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            formattedDate,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class BubbleTailPainter extends CustomPainter {
  final bool isUser;

  BubbleTailPainter({required this.isUser});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isUser ? Colors.blue : Colors.grey.shade300
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(isUser ? -20 : 20, 5);
    path.lineTo(isUser ? 10 : -10, 12);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  _LoadingDotsState createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 1), vsync: this)..repeat();
    _dotCount = StepTween(begin: 1, end: 4).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotCount,
      builder: (context, child) {
        String dots = '•' * _dotCount.value;
        return Text(
          '$dots',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}







