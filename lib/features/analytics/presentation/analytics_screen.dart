import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shared/widgets/responsive_layout.dart';
import '../../../core/theme/theme.dart';
import '../../../core/localization/localization.dart';
import '../../auth/presentation/auth_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  static const Map<String, List<String>> _workshopSkills = {
    'bakery': ['Baking', 'Packaging', 'Oven Safety', 'Hygiene'],
    'woodwork': ['Sanding', 'Cutting', 'Carpentry Tools', 'Safety Glasses'],
    'farming': ['Watering', 'Weeding', 'Harvesting', 'Tool Care'],
    'textile': ['Weaving', 'Stitching', 'Color Selection', 'Loom Operation'],
    'artwork': ['Painting', 'Clay Modeling', 'Paper Crafting', 'Drawing'],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?.role;
    final isWorkshopStaff = role == 'workshop_staff';
    final isPhysio = role == 'physiotherapist';
    final isSpeech = role == 'speech_therapist';
    final isMedical = role == 'medical_officer';
    final workshopId = user?.workshopId;

    String titleText = 'RAMS Institutional Performance & Progress Analytics';
    String descText = 'Interactive analysis engine monitoring overall attendance trends, IEP completions, skill growths and clinical logs.';
    
    if (isWorkshopStaff && workshopId != null) {
      final String workshopName = localizations.translate(workshopId);
      titleText = '$workshopName Workshop Performance & Progress Analytics';
      descText = 'Interactive analysis engine monitoring attendance, IEP goals, and skill growth for the $workshopName workshop.';
    } else if (isPhysio) {
      titleText = 'Physiotherapy Performance & Progress Analytics';
      descText = 'Interactive analysis engine monitoring physiotherapy sessions, motor milestones, and motor skill growth.';
    } else if (isSpeech) {
      titleText = 'Speech Therapy Performance & Progress Analytics';
      descText = 'Interactive analysis engine monitoring speech sessions, communication goals, and language progress.';
    } else if (isMedical) {
      titleText = 'Medical & Health Records Analytics';
      descText = 'Interactive analysis engine monitoring institutional consultations, prescription compliance, and vitals updates.';
    }

    // Determine Chart Cards titles
    String card1Title = 'Daily Attendance Trends (Last 7 Days)';
    String card2Title = 'IEP Goal Completion Status';
    String card3Title = 'Vocational Skill Growth Rate by Workshop';
    String card4Title = 'Daily Friend Mood Logs Distribution';

    if (isWorkshopStaff) {
      card1Title = 'Workshop Attendance Trends (Last 7 Days)';
      card2Title = 'Workshop IEP Goal Completion Status';
      if (workshopId != null) {
        card3Title = 'Skill Growth Rate: ${localizations.translate(workshopId)}';
      }
      card4Title = 'Workshop Friend Mood Logs Distribution';
    } else if (isPhysio) {
      card1Title = 'Therapy Session Attendance (Last 7 Days)';
      card2Title = 'Physiotherapy Goal Completion Status';
      card3Title = 'Motor Skill Growth Rate';
      card4Title = 'Mood Logs during Therapy Distribution';
    } else if (isSpeech) {
      card1Title = 'Speech Session Attendance (Last 7 Days)';
      card2Title = 'Speech Therapy Goal Completion Status';
      card3Title = 'Communication Skill Growth Rate';
      card4Title = 'Engagement/Mood during Speech Sessions';
    } else if (isMedical) {
      card1Title = 'Weekly Medical Consultations (Last 7 Days)';
      card2Title = 'Prescription Adherence & Compliance Status';
      card3Title = 'Vitals Tracking Compliance Rate';
      card4Title = 'Friend Mood Logs / Emotional State Distribution';
    }

    return ResponsiveLayout(
      title: localizations.translate('analytics'),
      currentRoute: '/analytics',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analytics Title
            Text(
              titleText,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              descText,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Responsive Layout for Cards
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth >= 800 ? 2 : 1;
                double aspectRatio = constraints.maxWidth < 450 ? 1.0 : (constraints.maxWidth < 600 ? 1.2 : 1.4);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: aspectRatio,
                  children: [
                    _buildAnalyticsChartCard(
                      context,
                      title: card1Title,
                      chartContent: _buildBarChartMock(context, role),
                    ),
                    _buildAnalyticsChartCard(
                      context,
                      title: card2Title,
                      chartContent: _buildPieChartMock(context, role),
                    ),
                    _buildAnalyticsChartCard(
                      context,
                      title: card3Title,
                      chartContent: _buildSkillGrowthMock(context, role, workshopId),
                    ),
                    _buildAnalyticsChartCard(
                      context,
                      title: card4Title,
                      chartContent: _buildMoodDistributionMock(context, role),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsChartCard(
    BuildContext context, {
    required String title,
    required Widget chartContent,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Expanded(child: chartContent),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartMock(BuildContext context, String? role) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Customize rates per role
    final List<double> rates;
    if (role == 'workshop_staff') {
      rates = [0.96, 0.94, 0.95, 0.92, 0.98, 0.88, 0.0];
    } else if (role == 'physiotherapist') {
      rates = [0.90, 0.88, 0.92, 0.85, 0.94, 0.80, 0.0];
    } else if (role == 'speech_therapist') {
      rates = [0.85, 0.90, 0.88, 0.82, 0.91, 0.78, 0.0];
    } else if (role == 'medical_officer') {
      rates = [0.60, 0.80, 0.70, 0.90, 0.50, 0.40, 0.0]; // scaled representation
    } else {
      rates = [0.95, 0.90, 0.92, 0.88, 0.96, 0.85, 0.0];
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(days.length, (index) {
        final rate = rates[index];
        final label = (role == 'medical_officer')
            ? (rate > 0 ? '${(rate * 15).toInt()}' : '-')
            : (rate > 0 ? '${(rate * 100).toInt()}%' : '-');
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              width: 24,
              height: rate > 0 ? 120 * rate : 2,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(rate > 0 ? 0.85 : 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(days[index], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        );
      }),
    );
  }

  Widget _buildPieChartMock(BuildContext context, String? role) {
    int completedCount = 52;
    int inProgressCount = 28;
    int pendingCount = 10;
    int delayedCount = 5;
    
    if (role == 'workshop_staff') {
      completedCount = 14; inProgressCount = 8; pendingCount = 3; delayedCount = 1;
    } else if (role == 'physiotherapist') {
      completedCount = 18; inProgressCount = 10; pendingCount = 4; delayedCount = 2;
    } else if (role == 'speech_therapist') {
      completedCount = 15; inProgressCount = 12; pendingCount = 3; delayedCount = 1;
    } else if (role == 'medical_officer') {
      completedCount = 45; inProgressCount = 10; pendingCount = 3; delayedCount = 2;
    }
    
    final total = completedCount + inProgressCount + pendingCount + delayedCount;
    final pct = total > 0 ? ((completedCount / total) * 100).toInt() : 0;

    // Legends change for medical officer
    final String legend1 = (role == 'medical_officer') ? 'Fully Compliant ($completedCount)' : 'Completed ($completedCount)';
    final String legend2 = (role == 'medical_officer') ? 'Partially Compliant ($inProgressCount)' : 'In Progress ($inProgressCount)';
    final String legend3 = (role == 'medical_officer') ? 'Non-Compliant ($pendingCount)' : 'Pending ($pendingCount)';
    final String legend4 = (role == 'medical_officer') ? 'Refused / Suspended ($delayedCount)' : 'Delayed ($delayedCount)';

    final double width = MediaQuery.of(context).size.width;
    final bool useColumn = width < 480;

    final chartWidget = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            AppTheme.successColor,
            AppTheme.primaryColor,
            AppTheme.accentColor,
            Colors.purple.shade300,
          ],
          stops: const [0.0, 0.5, 0.8, 1.0],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 34,
          backgroundColor: Colors.white,
          child: Text(
            '$pct%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
          ),
        ),
      ),
    );

    final legendsWidget = useColumn
        ? Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(legend1, AppTheme.successColor),
              _buildLegendItem(legend2, AppTheme.primaryColor),
              _buildLegendItem(legend3, AppTheme.accentColor),
              _buildLegendItem(legend4, Colors.purple.shade300),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(legend1, AppTheme.successColor),
              _buildLegendItem(legend2, AppTheme.primaryColor),
              _buildLegendItem(legend3, AppTheme.accentColor),
              _buildLegendItem(legend4, Colors.purple.shade300),
            ],
          );

    if (useColumn) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          chartWidget,
          const SizedBox(height: 8),
          legendsWidget,
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          chartWidget,
          const SizedBox(width: 24),
          legendsWidget,
        ],
      );
    }
  }

  Widget _buildLegendItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSkillGrowthMock(BuildContext context, String? role, String? workshopId) {
    final List<String> labels;
    final List<double> growth;

    if (role == 'workshop_staff' && workshopId != null && _workshopSkills.containsKey(workshopId)) {
      labels = _workshopSkills[workshopId]!;
      growth = [0.88, 0.82, 0.75, 0.90];
    } else if (role == 'physiotherapist') {
      labels = ['Gross Motor', 'Fine Motor', 'Balance', 'Coordination'];
      growth = [0.85, 0.80, 0.76, 0.88];
    } else if (role == 'speech_therapist') {
      labels = ['Receptive Lang.', 'Expressive Lang.', 'Vocabulary', 'Articulation'];
      growth = [0.90, 0.85, 0.82, 0.78];
    } else if (role == 'medical_officer') {
      labels = ['Blood Pressure', 'Blood Sugar', 'Weight Check', 'General Vitals'];
      growth = [0.95, 0.90, 0.88, 0.96];
    } else {
      labels = ['Bakery', 'Textile', 'Woodwork', 'Farming', 'Artwork'];
      growth = [0.85, 0.78, 0.90, 0.82, 0.70];
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(labels.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              SizedBox(width: 90, child: Text(labels[index], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: growth[index],
                    minHeight: 8,
                    color: AppTheme.primaryColor,
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('+${(growth[index] * 10).toInt()}% MoM', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMoodDistributionMock(BuildContext context, String? role) {
    final moods = ['Excellent', 'Good', 'Neutral', 'Agitated', 'Withdrawn'];
    final List<int> counts;
    
    if (role == 'workshop_staff') {
      counts = [12, 10, 5, 1, 0];
    } else if (role == 'physiotherapist') {
      counts = [15, 11, 4, 2, 1];
    } else if (role == 'speech_therapist') {
      counts = [14, 12, 3, 1, 0];
    } else if (role == 'medical_officer') {
      counts = [18, 16, 10, 4, 2];
    } else {
      counts = [42, 35, 18, 4, 1];
    }
    
    final total = counts.reduce((a, b) => a + b);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(moods.length, (index) {
        final percentage = total > 0 ? (counts[index] / total) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(width: 70, child: Text(moods[index], style: const TextStyle(fontSize: 12))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 12,
                    color: AppTheme.secondaryColor,
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(percentage * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }),
    );
  }
}
