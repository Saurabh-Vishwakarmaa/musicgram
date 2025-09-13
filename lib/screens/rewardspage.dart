import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RewardsPage extends StatefulWidget {
  @override
  _RewardsPageState createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final List<Reward> rewards = [
    Reward('Free Month of Premium', 'Listen for 100 minutes', 100),
    Reward('Exclusive Playlist', 'Listen for 50 minutes', 50),
    Reward('Early Access to New Releases', 'Listen for 200 minutes', 200),
    Reward('Virtual Concert Ticket', 'Listen for 300 minutes', 300),
    Reward('Custom Playlist Cover', 'Listen for 25 minutes', 25),
  ];

  final String comingSoonLabel = 'To be soon';

  int _totalListeningTimeMinutes = 0;
  int _userLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadListeningTime();
  }

  Future<void> _loadListeningTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalListeningTimeMinutes = prefs.getInt('listening_time') ?? 0;
      _userLevel = (prefs.getInt('user_level') ?? 1);
      for (var reward in rewards) {
        reward.currentProgress = _totalListeningTimeMinutes;
      }
    });
  }

  String get listeningTimeInMinutes => '$_totalListeningTimeMinutes minutes';

  Reward? get _nextReward {
    for (final reward in rewards) {
      if (reward.currentProgress < reward.requiredProgress) return reward;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final nextReward = _nextReward;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(nextReward),
            _buildSummaryRow(),

            // New static additions
            _buildSectionTitle('Daily Streak'),
            _buildDailyStreak(),

            _buildSectionTitle('Weekly Quests ($comingSoonLabel)'),
            _buildQuestsSection(),

            _buildSectionTitle('Your Rewards'),
            ...rewards.map(_buildRewardCard).toList(),

            _buildSectionTitle('Achievements ($comingSoonLabel)'),
            _buildBadgesGrid(),

            _buildSectionTitle('Season Pass ($comingSoonLabel)'),
            _buildSeasonPassCard(),

            _buildSectionTitle('Referral Program ($comingSoonLabel)'),
            _buildReferralCard(),

            _buildSectionTitle('Redeem Center ($comingSoonLabel)'),
            _buildRedeemCenter(),

            _buildSectionTitle('Leaderboard ($comingSoonLabel)'),
            _buildStaticComingSoonCard(Icons.leaderboard, 'Compete with friends for top listener spots!'),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Reward? nextReward) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'Rewards & Progress',
                style: GoogleFonts.firaSansCondensed(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              _soonPill(),
            ],
          ),
          SizedBox(height: 18),
          Row(
            children: [
              _buildStatBox('Level', '$_userLevel'),
              SizedBox(width: 16),
              _buildStatBox('Listening', listeningTimeInMinutes),
              SizedBox(width: 16),
              _buildStatBox('Rewards', '${rewards.where((r) => r.isUnlocked).length}/${rewards.length}'),
            ],
          ),
          if (nextReward != null) ...[
            SizedBox(height: 18),
            Text(
              'Next Reward:',
              style: GoogleFonts.firaSansCondensed(color: Colors.white70, fontSize: 16),
            ),
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.yellowAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  nextReward.name,
                  style: GoogleFonts.firaSansCondensed(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '(${nextReward.currentProgress}/${nextReward.requiredProgress} min)',
                  style: GoogleFonts.firaSansCondensed(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.firaSansCondensed(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.firaSansCondensed(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem(Icons.headphones, 'Listening Time', listeningTimeInMinutes),
          _buildSummaryItem(Icons.emoji_events, 'Level', '$_userLevel'),
          _buildSummaryItem(Icons.card_giftcard, 'Rewards', '${rewards.where((r) => r.isUnlocked).length}'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.greenAccent, size: 28),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.firaSansCondensed(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.firaSansCondensed(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 0, 8),
      child: Text(
        title,
        style: GoogleFonts.firaSansCondensed(
          color: Colors.greenAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // New: Daily Streak (static)
  Widget _buildDailyStreak() {
    const int streak = 3;
    const int totalDays = 7;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$streak-day streak',
            style: GoogleFonts.firaSansCondensed(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(totalDays, (i) {
              final active = i < streak;
              return Expanded(
                child: Container(
                  height: 16,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: active
                        ? LinearGradient(colors: [Colors.greenAccent, Colors.green])
                        : null,
                    color: active ? null : Colors.white24,
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: _soonTag()),
        ],
      ),
    );
  }

  // New: Weekly Quests (static)
  Widget _buildQuestsSection() {
    return Column(
      children: [
        _buildQuestCard(
          title: 'Play 10 songs',
          desc: 'Any songs, any time',
          current: 4,
          total: 10,
        ),
        _buildQuestCard(
          title: 'Listen for 30 minutes',
          desc: 'Keep the vibes going',
          current: 18,
          total: 30,
        ),
        _buildQuestCard(
          title: 'Follow 3 artists',
          desc: 'Grow your music circle',
          current: 1,
          total: 3,
        ),
      ],
    );
  }

  Widget _buildQuestCard({
    required String title,
    required String desc,
    required int current,
    required int total,
  }) {
    final progress = (current / total).clamp(0, 1).toDouble();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.firaSansCondensed(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 4),
          Text(desc, style: GoogleFonts.firaSansCondensed(color: Colors.white70, fontSize: 13)),
          SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(colors: [Colors.greenAccent, Colors.green]),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$current / $total',
                  style: GoogleFonts.firaSansCondensed(color: Colors.white70, fontSize: 12)),
              _soonChip(),
            ],
          ),
        ],
      ),
    );
  }

  // Existing reward card
  Widget _buildRewardCard(Reward reward) {
    double progress = reward.currentProgress / reward.requiredProgress;
    bool isUnlocked = progress >= 1;

    return AnimatedContainer(
      duration: Duration(milliseconds: 400),
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.green.withOpacity(0.18) : Colors.white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? Colors.greenAccent : Colors.white12,
          width: 2,
        ),
        boxShadow: [
          if (isUnlocked)
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUnlocked ? Icons.lock_open : Icons.lock,
                color: isUnlocked ? Colors.greenAccent : Colors.white54,
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  reward.name,
                  style: GoogleFonts.firaSansCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? Colors.greenAccent : Colors.white,
                  ),
                ),
              ),
              if (!isUnlocked) _soonChip(),
            ],
          ),
          SizedBox(height: 6),
          Text(
            reward.description,
            style: GoogleFonts.firaSansCondensed(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 14),
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              AnimatedContainer(
                duration: Duration(milliseconds: 600),
                height: 12,
                width: (progress.clamp(0, 1)) * MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.greenAccent : Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${reward.currentProgress}/${reward.requiredProgress} min',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              if (isUnlocked)
                Text(
                  'Unlocked!',
                  style: GoogleFonts.firaSansCondensed(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // New: Badges grid (static)
  Widget _buildBadgesGrid() {
    final badges = List.generate(6, (i) => 'Badge ${i + 1}');
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: badges.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, i) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.greenAccent, size: 28),
                    SizedBox(height: 8),
                    Text(
                      badges[i],
                      style: GoogleFonts.firaSansCondensed(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: _soonTag(),
              ),
            ],
          );
        },
      ),
    );
  }

  // New: Season pass (static)
  Widget _buildSeasonPassCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700.withOpacity(0.4), Colors.indigo.shade700.withOpacity(0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.military_tech, color: Colors.purpleAccent),
            SizedBox(width: 8),
            Text('Season 1: Rhythm Rise',
                style: GoogleFonts.firaSansCondensed(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Spacer(),
            _soonChip(color: Colors.purpleAccent),
          ]),
          SizedBox(height: 12),
          _seasonTrack('Free track', 0.35, Colors.greenAccent),
          SizedBox(height: 10),
          _seasonTrack('Pro track', 0.10, Colors.amberAccent, locked: true),
        ],
      ),
    );
  }

  Widget _seasonTrack(String label, double progress, Color color, {bool locked = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (locked) Icon(Icons.lock, size: 14, color: Colors.white54),
          if (locked) SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.firaSansCondensed(color: Colors.white70, fontSize: 13)),
          Spacer(),
          Text('${(progress * 100).round()}%',
              style: GoogleFonts.firaSansCondensed(color: Colors.white70, fontSize: 12)),
        ]),
        SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // New: Referral program (static)
  Widget _buildReferralCard() {
    const code = 'MG-1X2Y';
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.group_add, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Invite friends',
                style: GoogleFonts.firaSansCondensed(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Spacer(),
            _soonChip(),
          ]),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Text('Your code: ',
                    style: GoogleFonts.firaSansCondensed(color: Colors.white70, fontSize: 14)),
                Text(code,
                    style: GoogleFonts.firaSansCondensed(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Spacer(),
                _disabledPill('Copy'),
                SizedBox(width: 8),
                _disabledPill('Invite'),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Friends get 7 days Premium. You get points.',
            style: GoogleFonts.firaSansCondensed(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // New: Redeem center (static)
  Widget _buildRedeemCenter() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.redeem, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Redeem a code',
                style: GoogleFonts.firaSansCondensed(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Spacer(),
            _soonChip(),
          ]),
          SizedBox(height: 12),
          AbsorbPointer(
            absorbing: true,
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Enter gift or promo code',
                hintStyle: GoogleFonts.firaSansCondensed(color: Colors.white38),
                filled: true,
                fillColor: Colors.black,
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(10),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: GoogleFonts.firaSansCondensed(color: Colors.white),
            ),
          ),
          SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: _disabledPill('Redeem')),
        ],
      ),
    );
  }

  // Static "Coming soon" card (reused)
  Widget _buildStaticComingSoonCard(IconData icon, String text) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.greenAccent, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.firaSansCondensed(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ),
          _soonPill(),
        ],
      ),
    );
  }

  // Small helpers
  Widget _soonTag({Color color = Colors.greenAccent}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        comingSoonLabel,
        style: GoogleFonts.firaSansCondensed(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _soonChip({Color color = Colors.greenAccent}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        comingSoonLabel,
        style: GoogleFonts.firaSansCondensed(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _soonPill({Color color = Colors.greenAccent}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            comingSoonLabel,
            style: GoogleFonts.firaSansCondensed(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _disabledPill(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: GoogleFonts.firaSansCondensed(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class Reward {
  final String name;
  final String description;
  final int requiredProgress;
  int currentProgress;

  Reward(this.name, this.description, this.requiredProgress, [this.currentProgress = 0]);

  bool get isUnlocked => currentProgress >= requiredProgress;
}
