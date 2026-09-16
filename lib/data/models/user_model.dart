import 'package:spillcity/data/database/local_db.dart';

class UserModel {
  final String id;
  final String name;
  final String? username;
  final String? email;
  final String? avatar;
  final String? localAvatar;
  final String? college;
  final String? bio;
  final int followers;
  final int following;
  final int postsCount;
  final bool onboardingComplete;
  final String? role;

  // Settings & Privacy fields
  final bool isPrivate;
  final bool showActivityStatus;
  final String commentPrivacy;
  final String mentionPrivacy;
  final bool notifyLikes;
  final bool notifyComments;
  final bool notifyMentions;
  final bool notifyNewPosts;
  final String callPrivacy;
  final String callQuality;

  // New onboarding & profile fields
  final String? branch;
  final String? department;
  final String? phone;
  final String? dateOfBirth;
  final String? gender;
  final String? links;
  final String? profilePicture;

  String get resolvedAvatarUrl {
    if (profilePicture != null && profilePicture!.isNotEmpty) return profilePicture!;
    if (avatar != null && avatar!.isNotEmpty) return avatar!;
    if (localAvatar != null && localAvatar!.isNotEmpty) return localAvatar!;
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff&size=200';
  }

  UserModel({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.avatar,
    this.localAvatar,
    this.college,
    this.bio,
    this.followers = 0,
    this.following = 0,
    this.postsCount = 0,
    this.onboardingComplete = false,
    this.role = 'user',
    this.isPrivate = false,
    this.showActivityStatus = true,
    this.commentPrivacy = 'Everyone',
    this.mentionPrivacy = 'Everyone',
    this.notifyLikes = true,
    this.notifyComments = true,
    this.notifyMentions = true,
    this.notifyNewPosts = false,
    this.callPrivacy = 'everyone',
    this.callQuality = 'hd',
    this.branch,
    this.department,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.links,
    this.profilePicture,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'User',
      username: json['username'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String? ?? json['image'] as String?,
      localAvatar: json['localAvatar'] as String?,
      college: json['college'] as String?,
      bio: json['bio'] as String?,
      followers: json['followers'] as int? ?? 0,
      following: json['following'] as int? ?? 0,
      postsCount: json['postsCount'] as int? ?? json['posts_count'] as int? ?? 0,
      onboardingComplete: json['onboardingComplete'] as bool? ?? json['onboarding_complete'] as bool? ?? false,
      role: json['role'] as String? ?? 'user',
      isPrivate: json['is_private'] as bool? ?? json['isPrivate'] as bool? ?? false,
      showActivityStatus: json['show_activity_status'] as bool? ?? json['showActivityStatus'] as bool? ?? true,
      commentPrivacy: json['comment_privacy'] as String? ?? json['commentPrivacy'] as String? ?? 'Everyone',
      mentionPrivacy: json['mention_privacy'] as String? ?? json['mentionPrivacy'] as String? ?? 'Everyone',
      notifyLikes: json['notify_likes'] as bool? ?? json['notifyLikes'] as bool? ?? true,
      notifyComments: json['notify_comments'] as bool? ?? json['notifyComments'] as bool? ?? true,
      notifyMentions: json['notify_mentions'] as bool? ?? json['notifyMentions'] as bool? ?? true,
      notifyNewPosts: json['notify_new_posts'] as bool? ?? json['notifyNewPosts'] as bool? ?? false,
      callPrivacy: json['call_privacy'] as String? ?? json['callPrivacy'] as String? ?? 'everyone',
      callQuality: json['call_quality'] as String? ?? json['callQuality'] as String? ?? 'hd',
      branch: json['branch'] as String?,
      department: json['department'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] as String? ?? json['dateOfBirth'] as String?,
      gender: json['gender'] as String?,
      links: json['links'] as String?,
      profilePicture: json['profile_picture'] as String? ?? json['profilePicture'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'avatar': avatar,
      'localAvatar': localAvatar,
      'college': college,
      'bio': bio,
      'followers': followers,
      'following': following,
      'postsCount': postsCount,
      'onboardingComplete': onboardingComplete,
      'role': role,
      'is_private': isPrivate,
      'show_activity_status': showActivityStatus,
      'comment_privacy': commentPrivacy,
      'mention_privacy': mentionPrivacy,
      'notify_likes': notifyLikes,
      'notify_comments': notifyComments,
      'notify_mentions': notifyMentions,
      'notify_new_posts': notifyNewPosts,
      'call_privacy': callPrivacy,
      'call_quality': callQuality,
      'branch': branch,
      'department': department,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'links': links,
      'profile_picture': profilePicture,
    };
  }

  // Convert to Drift Table Row object
  LocalUserProfile toDrift() {
    return LocalUserProfile(
      id: id,
      name: name,
      username: username,
      email: email,
      avatar: avatar,
      localAvatar: localAvatar,
      college: college,
      bio: bio,
      followers: followers,
      following: following,
      postsCount: postsCount,
      onboardingComplete: onboardingComplete,
      lastSynced: DateTime.now().toIso8601String(),
      branch: branch,
      department: department,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gender: gender,
      links: links,
      profilePicture: profilePicture,
      // Settings fields
      role: role ?? 'user',
      isPrivate: isPrivate,
      showActivityStatus: showActivityStatus,
      commentPrivacy: commentPrivacy,
      mentionPrivacy: mentionPrivacy,
      notifyLikes: notifyLikes,
      notifyComments: notifyComments,
      notifyMentions: notifyMentions,
      notifyNewPosts: notifyNewPosts,
      callPrivacy: callPrivacy,
      callQuality: callQuality,
    );
  }

  // Create from Drift Table Row object
  factory UserModel.fromDrift(LocalUserProfile u) {
    return UserModel(
      id: u.id,
      name: u.name ?? '',
      username: u.username,
      email: u.email,
      avatar: u.avatar,
      localAvatar: u.localAvatar,
      college: u.college,
      bio: u.bio,
      followers: u.followers,
      following: u.following,
      postsCount: u.postsCount,
      onboardingComplete: u.onboardingComplete,
      branch: u.branch,
      department: u.department,
      phone: u.phone,
      dateOfBirth: u.dateOfBirth,
      gender: u.gender,
      links: u.links,
      profilePicture: u.profilePicture,
      // Settings fields
      role: u.role,
      isPrivate: u.isPrivate,
      showActivityStatus: u.showActivityStatus,
      commentPrivacy: u.commentPrivacy,
      mentionPrivacy: u.mentionPrivacy,
      notifyLikes: u.notifyLikes,
      notifyComments: u.notifyComments,
      notifyMentions: u.notifyMentions,
      notifyNewPosts: u.notifyNewPosts,
      callPrivacy: u.callPrivacy,
      callQuality: u.callQuality,
    );
  }
}
