import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductivityAnalyticsScreen extends StatelessWidget {
  final String userId;

  const ProductivityAnalyticsScreen({Key? key, required this.userId})
    : super(key: key);

  Future<List<FlSpot>> _getWeeklyFocusScores() async {
    final now = DateTime.now();
    final firestore = FirebaseFirestore.instance;
    final spots = <FlSpot>[];

    try {
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final formatted =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        print("Looking for document: $formatted");
        final doc =
            await firestore
                .collection('users')
                .doc(userId)
                .collection('analytics')
                .doc(formatted)
                .get();

        final data = doc.data();
        print("Fetched data for $formatted: $data");

        double score = 0;
        if (doc.exists && data != null && data.containsKey('focusScore')) {
          final rawScore = data['focusScore'];
          print("Raw Score: $rawScore (${rawScore.runtimeType})");
          score = (rawScore as num).toDouble();
        } else {
          print("No valid focusScore for $formatted");
        }

        spots.add(FlSpot((6 - i).toDouble(), score));
      }
    } catch (e) {
      print("Error fetching focus scores: $e");
      rethrow;
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productivity Trend')),
      body: FutureBuilder<List<FlSpot>>(
        future: _getWeeklyFocusScores(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No focus data available.'));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final day = DateTime.now().subtract(
                          Duration(days: 6 - value.toInt()),
                        );
                        return Text(DateFormat.E().format(day));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: snapshot.data!,
                    isCurved: true,
                    barWidth: 2,
                    color: Colors.blue,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
