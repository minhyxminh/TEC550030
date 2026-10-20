class BuddyProfile {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? avatarPath;
  final int? age;
  final String? gender;
  final bool showAge;
  final bool showGender;
  final String? homeGymId;
  final String? gymName;
  final String? district;

  final bool enabled;
  final String? fitnessGoal;
  final String? experienceLevel;
  final List<String> favoriteWorkouts;
  final List<String> preferredWorkoutTimes;
  final List<String> workoutStyle;
  final String? bio;
  final bool onboardingCompleted;

  final bool lookingForPartner;
  final String? partnerDate;
  final String? partnerStartTime;
  final String? partnerEndTime;
  final String? partnerWorkout;
  final String? partnerGymId;
  final String? partnerGymName;
  final String? partnerNote;

  const BuddyProfile({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.avatarPath,
    this.age,
    this.gender,
    this.showAge = true,
    this.showGender = true,
    this.homeGymId,
    this.gymName,
    this.district,
    this.enabled = true,
    this.fitnessGoal,
    this.experienceLevel,
    this.favoriteWorkouts = const [],
    this.preferredWorkoutTimes = const [],
    this.workoutStyle = const [],
    this.bio,
    this.onboardingCompleted = false,
    this.lookingForPartner = false,
    this.partnerDate,
    this.partnerStartTime,
    this.partnerEndTime,
    this.partnerWorkout,
    this.partnerGymId,
    this.partnerGymName,
    this.partnerNote,
  });

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  factory BuddyProfile.fromJson(Map<String, dynamic> json) {
    return BuddyProfile(
      userId: json['user_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      avatarPath: json['avatar_path'] as String?,
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      showAge: json['show_age'] as bool? ?? true,
      showGender: json['show_gender'] as bool? ?? true,
      homeGymId: json['home_gym_id'] as String?,
      gymName: json['gym_name'] as String?,
      district: json['district'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      fitnessGoal: json['fitness_goal'] as String?,
      experienceLevel: json['experience_level'] as String?,
      favoriteWorkouts: _parseStringList(json['favorite_workouts']),
      preferredWorkoutTimes: _parseStringList(json['preferred_workout_times']),
      workoutStyle: _parseStringList(json['workout_style']),
      bio: json['bio'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      lookingForPartner: json['looking_for_partner'] as bool? ?? false,
      partnerDate: json['partner_date'] as String?,
      partnerStartTime: json['partner_start_time'] as String?,
      partnerEndTime: json['partner_end_time'] as String?,
      partnerWorkout: json['partner_workout'] as String?,
      partnerGymId: json['partner_gym_id'] as String?,
      partnerGymName: json['partner_gym_name'] as String?,
      partnerNote: json['partner_note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (avatarPath != null) 'avatar_path': avatarPath,
    'age': age,
    'gender': gender,
    'show_age': showAge,
    'show_gender': showGender,
    'home_gym_id': homeGymId,
    'gym_name': gymName,
    'district': district,
    'enabled': enabled,
    'fitness_goal': fitnessGoal,
    'experience_level': experienceLevel,
    'favorite_workouts': favoriteWorkouts,
    'preferred_workout_times': preferredWorkoutTimes,
    'workout_style': workoutStyle,
    'bio': bio,
    'onboarding_completed': onboardingCompleted,
    'looking_for_partner': lookingForPartner,
    'partner_date': partnerDate,
    'partner_start_time': partnerStartTime,
    'partner_end_time': partnerEndTime,
    'partner_workout': partnerWorkout,
    'partner_gym_id': partnerGymId,
    'partner_gym_name': partnerGymName,
    'partner_note': partnerNote,
  };
}

