import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ===== 디자인 시스템 (Dark + Neon) =====
class BB {
  // 배경 톤 (중성 다크, 푸른 기 제거)
  static const bg = Color(0xFF0E0E0F);           // 가장 어두운 배경
  static const surface = Color(0xFF1A1A1B);      // 카드 배경
  static const surfaceHigh = Color(0xFF252527);  // 강조 카드
  static const border = Color(0xFF2E2E30);

  // 텍스트
  static const text = Color(0xFFF4F4F5);
  static const textDim = Color(0xFFA1A1AA);
  static const textFaint = Color(0xFF71717A);

  // 네온 액센트
  static const neonPurple = Color(0xFFA78BFA);   // 메인 (CTA, 강조)
  static const neonCyan = Color(0xFF22D3EE);     // 보조 (포인트)
  static const neonPink = Color(0xFFEC4899);     // 강한 강조 (인기)
  static const neonGreen = Color(0xFF34D399);    // 성공
  static const neonYellow = Color(0xFFFCD34D);   // 경고
  static const neonRed = Color(0xFFF87171);      // 위험

  // 카드 라운드
  static const radius = 16.0;
  static const radiusS = 12.0;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.load(); // 저장된 로그인 복원
  runApp(const BangbangApp());
}

/// 매장 데이터 모델 (백엔드 StoreDto에 대응)
class Store {
  final int id;
  final String name;
  final String region;     // 권역 (서울/경기·인천/...)
  final String subRegion;  // 세부 지역 (홍대/합정/강남)
  final String address;
  final String genre;
  final int themeCount;
  final double latitude;
  final double longitude;

  Store({
    required this.id,
    required this.name,
    required this.region,
    required this.subRegion,
    required this.address,
    required this.genre,
    required this.themeCount,
    required this.latitude,
    required this.longitude,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      name: json['name'],
      region: json['region'] ?? '',
      subRegion: json['subRegion'] ?? '',
      address: json['address'],
      genre: json['genre'],
      themeCount: json['themeCount'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// 난이도(1~5) → 텍스트 라벨. 별점(리뷰 평점)과 헷갈리지 않게 텍스트로 표현.
String difficultyLabel(int difficulty) {
  switch (difficulty) {
    case 1:
      return '매우 쉬움';
    case 2:
      return '쉬움';
    case 3:
      return '보통';
    case 4:
      return '어려움';
    case 5:
      return '매우 어려움';
    default:
      return '-';
  }
}

/// 테마 데이터 모델 (백엔드 ThemeDto에 대응)
/// 주의: Flutter의 ThemeData와 이름 충돌 피하려고 EscapeTheme으로 명명
class EscapeTheme {
  final int id;
  final int storeId;
  final String name;
  final String genre;
  final int difficulty;
  final int minPeople;
  final int maxPeople;
  final int durationMin;
  final int price;
  final String description;

  EscapeTheme({
    required this.id,
    required this.storeId,
    required this.name,
    required this.genre,
    required this.difficulty,
    required this.minPeople,
    required this.maxPeople,
    required this.durationMin,
    required this.price,
    required this.description,
  });

  factory EscapeTheme.fromJson(Map<String, dynamic> json) {
    return EscapeTheme(
      id: json['id'],
      storeId: json['storeId'],
      name: json['name'],
      genre: json['genre'],
      difficulty: json['difficulty'],
      minPeople: json['minPeople'],
      maxPeople: json['maxPeople'],
      durationMin: json['durationMin'],
      price: json['price'],
      description: json['description'],
    );
  }
}

/// 권역 통계 모델 (백엔드 RegionStatsDto에 대응)
class RegionStats {
  final String region;
  final int storeCount;
  final String grade;
  final String colorHex;

  RegionStats({
    required this.region,
    required this.storeCount,
    required this.grade,
    required this.colorHex,
  });

  factory RegionStats.fromJson(Map<String, dynamic> json) {
    return RegionStats(
      region: json['region'],
      storeCount: json['storeCount'],
      grade: json['grade'],
      colorHex: json['color'],
    );
  }

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

/// GET /api/regions/stats
Future<List<RegionStats>> fetchRegionStats() async {
  final url = Uri.parse('http://localhost:3000/api/regions/stats');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    return data.map((item) => RegionStats.fromJson(item)).toList();
  } else {
    throw Exception('지도 통계를 불러오지 못했습니다 (${response.statusCode})');
  }
}

/// GET /api/regions/rating - 평점 모드 (RegionStats로 매핑)
Future<List<RegionStats>> fetchRegionRating() async {
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/regions/rating'),
  );
  if (res.statusCode != 200) {
    throw Exception('평점 통계를 불러오지 못했습니다 (${res.statusCode})');
  }
  final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
  return data.map((j) {
    final avg = j['averageRating'];
    return RegionStats(
      region: j['region'],
      storeCount: j['reviewCount'] ?? 0, // 리뷰 수 (0이면 회색 처리)
      grade: avg == null ? '리뷰없음' : '★${(avg as num).toStringAsFixed(1)}',
      colorHex: j['color'] ?? '#757575',
    );
  }).toList();
}

/// 도장깨기 모드 - region-progress를 RegionStats로 매핑 (로그인 필요)
Future<List<RegionStats>> fetchRegionConquest() async {
  final c = await fetchConquest();
  return c.regions
      .map((r) => RegionStats(
            region: r.region,
            storeCount: r.visitedStores, // 0이면 회색
            grade: '${r.percent}%',
            colorHex: r.colorHex,
          ))
      .toList();
}

// ===== 인증 (자체 로그인) =====

class AuthUser {
  final int userId;
  final String username;
  final String nickname;
  final String token;
  final bool isAdmin;

  AuthUser({
    required this.userId,
    required this.username,
    required this.nickname,
    required this.token,
    required this.isAdmin,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        userId: j['userId'],
        username: j['username'],
        nickname: j['nickname'] ?? j['username'],
        token: j['token'],
        isAdmin: j['admin'] ?? false,
      );
}

/// 토큰/유저 정보를 기기에 저장 (shared_preferences).
/// 앱 재시작해도 로그인 유지. 웹에선 localStorage 사용.
class AuthStore {
  static const _kToken = 'auth_token';
  static const _kUserId = 'auth_user_id';
  static const _kUsername = 'auth_username';
  static const _kNickname = 'auth_nickname';
  static const _kAdmin = 'auth_admin';

  static AuthUser? current;

  static Future<void> save(AuthUser u) async {
    current = u;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, u.token);
    await sp.setInt(_kUserId, u.userId);
    await sp.setString(_kUsername, u.username);
    await sp.setString(_kNickname, u.nickname);
    await sp.setBool(_kAdmin, u.isAdmin);
    await FavoriteStore.reload();
  }

  static Future<AuthUser?> load() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString(_kToken);
    if (token == null) return null;
    current = AuthUser(
      userId: sp.getInt(_kUserId) ?? 0,
      username: sp.getString(_kUsername) ?? '',
      nickname: sp.getString(_kNickname) ?? '',
      token: token,
      isAdmin: sp.getBool(_kAdmin) ?? false,
    );
    await FavoriteStore.reload();
    return current;
  }

  static Future<void> clear() async {
    current = null;
    FavoriteStore.ids = {};
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kUserId);
    await sp.remove(_kUsername);
    await sp.remove(_kNickname);
    await sp.remove(_kAdmin);
  }
}

/// POST /api/auth/signup
Future<AuthUser> signup(String username, String password,
    String nickname) async {
  final res = await http.post(
    Uri.parse('http://localhost:3000/api/auth/signup'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'username': username,
      'password': password,
      'nickname': nickname,
    }),
  );
  final body = json.decode(utf8.decode(res.bodyBytes));
  if (res.statusCode == 200) {
    return AuthUser.fromJson(body);
  }
  throw Exception(body['message'] ?? '회원가입 실패 (${res.statusCode})');
}

/// POST /api/auth/login
Future<AuthUser> login(String username, String password) async {
  final res = await http.post(
    Uri.parse('http://localhost:3000/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'username': username, 'password': password}),
  );
  final body = json.decode(utf8.decode(res.bodyBytes));
  if (res.statusCode == 200) {
    return AuthUser.fromJson(body);
  }
  throw Exception(body['message'] ?? '로그인 실패 (${res.statusCode})');
}

// ===== 리뷰 =====

class Review {
  final int id;
  final String username;
  final double rating;
  final String content;
  final bool isSuccess;
  final String createdAt;

  Review({
    required this.id,
    required this.username,
    required this.rating,
    required this.content,
    required this.isSuccess,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'],
        username: j['username'] ?? '익명',
        rating: (j['rating'] as num).toDouble(),
        content: j['content'] ?? '',
        isSuccess: j['isSuccess'] ?? false,
        createdAt: (j['createdAt'] ?? '').toString().split('T').first,
      );
}

class ReviewList {
  final int reviewCount;
  final bool ratingVisible;
  final double? averageRating;
  final List<Review> reviews;

  ReviewList({
    required this.reviewCount,
    required this.ratingVisible,
    required this.averageRating,
    required this.reviews,
  });

  factory ReviewList.fromJson(Map<String, dynamic> j) => ReviewList(
        reviewCount: j['reviewCount'] ?? 0,
        ratingVisible: j['ratingVisible'] ?? false,
        averageRating: j['averageRating'] == null
            ? null
            : (j['averageRating'] as num).toDouble(),
        reviews: ((j['reviews'] ?? []) as List)
            .map((e) => Review.fromJson(e))
            .toList(),
      );
}

/// GET /api/themes/{themeId}/reviews
Future<ReviewList> fetchReviews(int themeId) async {
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/themes/$themeId/reviews'),
  );
  if (res.statusCode == 200) {
    return ReviewList.fromJson(json.decode(utf8.decode(res.bodyBytes)));
  }
  throw Exception('리뷰를 불러오지 못했습니다 (${res.statusCode})');
}

/// POST /api/themes/{themeId}/reviews (로그인 필요)
Future<void> postReview(
  int themeId, {
  required double rating,
  required String content,
  required bool isSuccess,
}) async {
  final token = AuthStore.current?.token;
  if (token == null) throw Exception('로그인이 필요합니다');
  final res = await http.post(
    Uri.parse('http://localhost:3000/api/themes/$themeId/reviews'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: json.encode({
      'rating': rating,
      'content': content,
      'isSuccess': isSuccess,
    }),
  );
  if (res.statusCode == 200) return;
  final body = json.decode(utf8.decode(res.bodyBytes));
  throw Exception(body['message'] ?? '리뷰 작성 실패 (${res.statusCode})');
}

class MyReview {
  final int reviewId;
  final int themeId;
  final String themeName;
  final double rating;
  final String content;
  final bool isSuccess;
  final String createdAt;

  MyReview({
    required this.reviewId,
    required this.themeId,
    required this.themeName,
    required this.rating,
    required this.content,
    required this.isSuccess,
    required this.createdAt,
  });

  factory MyReview.fromJson(Map<String, dynamic> j) => MyReview(
        reviewId: j['reviewId'],
        themeId: j['themeId'],
        themeName: j['themeName'] ?? '',
        rating: (j['rating'] as num).toDouble(),
        content: j['content'] ?? '',
        isSuccess: j['isSuccess'] ?? false,
        createdAt: (j['createdAt'] ?? '').toString().split('T').first,
      );
}

/// GET /api/users/me/reviews (로그인 필요)
Future<List<MyReview>> fetchMyReviews() async {
  final token = AuthStore.current?.token;
  if (token == null) throw Exception('로그인이 필요합니다');
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/users/me/reviews'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode == 200) {
    final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
    return data.map((e) => MyReview.fromJson(e)).toList();
  }
  final body = json.decode(utf8.decode(res.bodyBytes));
  throw Exception(body['message'] ?? '내 리뷰를 불러오지 못했습니다');
}

class VisitedRoom {
  final int themeId;
  final String themeName;
  final String storeName;
  final String region;
  final bool isSuccess;
  final String clearedAt;

  VisitedRoom({
    required this.themeId,
    required this.themeName,
    required this.storeName,
    required this.region,
    required this.isSuccess,
    required this.clearedAt,
  });

  factory VisitedRoom.fromJson(Map<String, dynamic> j) => VisitedRoom(
        themeId: j['themeId'],
        themeName: j['themeName'] ?? '',
        storeName: j['storeName'] ?? '-',
        region: j['region'] ?? '',
        isSuccess: j['isSuccess'] ?? false,
        clearedAt: (j['clearedAt'] ?? '').toString().split('T').first,
      );
}

/// GET /api/users/me/clear-logs (로그인 필요)
Future<List<VisitedRoom>> fetchVisitedRooms() async {
  final token = AuthStore.current?.token;
  if (token == null) throw Exception('로그인이 필요합니다');
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/users/me/clear-logs'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode == 200) {
    final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
    return data.map((e) => VisitedRoom.fromJson(e)).toList();
  }
  final body = json.decode(utf8.decode(res.bodyBytes));
  throw Exception(body['message'] ?? '방문 기록을 불러오지 못했습니다');
}

// ===== 지역 선택 =====

class SubRegionCount {
  final String name;
  final int count;
  SubRegionCount(this.name, this.count);
  factory SubRegionCount.fromJson(Map<String, dynamic> j) =>
      SubRegionCount(j['name'] ?? '', j['count'] ?? 0);
}

class RegionSubregions {
  final String region;
  final int totalCount;
  final List<SubRegionCount> subRegions;
  RegionSubregions(this.region, this.totalCount, this.subRegions);
  factory RegionSubregions.fromJson(Map<String, dynamic> j) =>
      RegionSubregions(
        j['region'] ?? '',
        j['totalCount'] ?? 0,
        ((j['subRegions'] ?? []) as List)
            .map((e) => SubRegionCount.fromJson(e))
            .toList(),
      );
}

/// GET /api/regions/subregions
Future<List<RegionSubregions>> fetchSubregions() async {
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/regions/subregions'),
  );
  if (res.statusCode == 200) {
    final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
    return data.map((e) => RegionSubregions.fromJson(e)).toList();
  }
  throw Exception('지역 정보를 불러오지 못했습니다 (${res.statusCode})');
}

/// 지역 선택 바텀시트 — 좌: 권역 / 우: 세부지역+매장수
class RegionPickerSheet extends StatefulWidget {
  const RegionPickerSheet({super.key});

  @override
  State<RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<RegionPickerSheet> {
  late Future<List<RegionSubregions>> _future;
  int _selectedRegionIdx = 0;

  @override
  void initState() {
    super.initState();
    _future = fetchSubregions();
  }

  void _goList(String? subRegion) {
    Navigator.pop(context); // 시트 닫기
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(initialSubRegion: subRegion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Text(
                    '지역 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: BB.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: BB.textDim),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: BB.border),
            Expanded(
              child: FutureBuilder<List<RegionSubregions>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: BB.neonPurple),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return Center(
                      child: Text(
                        '${snap.error}'.replaceFirst('Exception: ', ''),
                        style: const TextStyle(color: BB.textDim),
                      ),
                    );
                  }
                  final regions = snap.data!;
                  if (_selectedRegionIdx >= regions.length) {
                    _selectedRegionIdx = 0;
                  }
                  final sel = regions[_selectedRegionIdx];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 좌: 권역 리스트
                      SizedBox(
                        width: 110,
                        child: ListView.builder(
                          itemCount: regions.length,
                          itemBuilder: (context, i) {
                            final r = regions[i];
                            final active = i == _selectedRegionIdx;
                            return InkWell(
                              onTap: () => setState(
                                  () => _selectedRegionIdx = i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 12,
                                ),
                                color: active
                                    ? BB.surface
                                    : Colors.transparent,
                                child: Text(
                                  r.region,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: active
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: active
                                        ? BB.neonPurple
                                        : BB.textDim,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const VerticalDivider(
                          width: 1, color: BB.border),
                      // 우: 세부지역 + 매장수
                      Expanded(
                        child: ListView(
                          controller: scrollCtrl,
                          children: [
                            // 권역 전체
                            _subTile(
                              '${sel.region} 전체',
                              sel.totalCount,
                              bold: true,
                              onTap: () => _goList(null),
                            ),
                            if (sel.subRegions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  '등록된 매장이 없어요',
                                  style: TextStyle(
                                      color: BB.textFaint,
                                      fontSize: 13),
                                ),
                              ),
                            ...sel.subRegions.map((s) => _subTile(
                                  s.name,
                                  s.count,
                                  onTap: () => _goList(s.name),
                                )),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _subTile(String name, int count,
      {bool bold = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BB.border)),
        ),
        child: Row(
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: BB.text,
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                color: BB.textDim,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 즐겨찾기 =====

/// 즐겨찾기 매장 ID 캐시 (로그인 세션 동안 유지, ♡ 상태 빠르게 판단)
class FavoriteStore {
  static Set<int> ids = {};

  static bool has(int storeId) => ids.contains(storeId);

  static Future<void> reload() async {
    final token = AuthStore.current?.token;
    if (token == null) {
      ids = {};
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('http://localhost:3000/api/favorites/ids'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final j = json.decode(utf8.decode(res.bodyBytes));
        ids = ((j['storeIds'] ?? []) as List)
            .map((e) => e as int)
            .toSet();
      }
    } catch (_) {
      // 실패해도 빈 상태 유지 (치명적 아님)
    }
  }

  /// 토글 → 서버 반영 + 캐시 갱신. 최종 상태(true=즐겨찾기됨) 반환.
  static Future<bool> toggle(int storeId) async {
    final token = AuthStore.current?.token;
    if (token == null) throw Exception('로그인이 필요합니다');
    final isFav = ids.contains(storeId);
    final res = await (isFav
        ? http.delete(
            Uri.parse('http://localhost:3000/api/favorites/$storeId'),
            headers: {'Authorization': 'Bearer $token'},
          )
        : http.post(
            Uri.parse('http://localhost:3000/api/favorites/$storeId'),
            headers: {'Authorization': 'Bearer $token'},
          ));
    if (res.statusCode != 200) {
      final b = json.decode(utf8.decode(res.bodyBytes));
      throw Exception(b['message'] ?? '즐겨찾기 처리 실패');
    }
    if (isFav) {
      ids.remove(storeId);
    } else {
      ids.add(storeId);
    }
    return !isFav;
  }
}

/// GET /api/favorites - 내 즐겨찾기 매장 목록
Future<List<Store>> fetchFavoriteStores() async {
  final token = AuthStore.current?.token;
  if (token == null) throw Exception('로그인이 필요합니다');
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/favorites'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode == 200) {
    final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
    return data.map((e) => Store.fromJson(e)).toList();
  }
  final b = json.decode(utf8.decode(res.bodyBytes));
  throw Exception(b['message'] ?? '즐겨찾기를 불러오지 못했습니다');
}

// ===== 내 프로필 (칭호) =====

class MyProfile {
  final String username;
  final String nickname;
  final int visitedCount;
  final String title; // 초보자 / 중급자 / 숙련자

  MyProfile({
    required this.username,
    required this.nickname,
    required this.visitedCount,
    required this.title,
  });

  factory MyProfile.fromJson(Map<String, dynamic> j) => MyProfile(
        username: j['username'] ?? '',
        nickname: j['nickname'] ?? '',
        visitedCount: j['visitedCount'] ?? 0,
        title: j['title'] ?? '초보자',
      );
}

/// GET /api/users/me/profile (로그인 필요)
Future<MyProfile> fetchMyProfile() async {
  final token = AuthStore.current?.token;
  if (token == null) throw Exception('로그인이 필요합니다');
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/users/me/profile'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode == 200) {
    return MyProfile.fromJson(json.decode(utf8.decode(res.bodyBytes)));
  }
  final b = json.decode(utf8.decode(res.bodyBytes));
  throw Exception(b['message'] ?? '프로필을 불러오지 못했습니다');
}

// ===== 도장깨기 진행도 =====

class RegionProgress {
  final String region;
  final int totalStores;
  final int visitedStores;
  final int percent;
  final String level;
  final String colorHex;

  RegionProgress({
    required this.region,
    required this.totalStores,
    required this.visitedStores,
    required this.percent,
    required this.level,
    required this.colorHex,
  });

  factory RegionProgress.fromJson(Map<String, dynamic> j) => RegionProgress(
        region: j['region'] ?? '',
        totalStores: j['totalStores'] ?? 0,
        visitedStores: j['visitedStores'] ?? 0,
        percent: j['percent'] ?? 0,
        level: j['level'] ?? '',
        colorHex: j['color'] ?? '#757575',
      );

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class ConquestProgress {
  final List<RegionProgress> regions;
  final int totalVisited;
  final int totalStores;
  final int overallPercent;

  ConquestProgress({
    required this.regions,
    required this.totalVisited,
    required this.totalStores,
    required this.overallPercent,
  });

  factory ConquestProgress.fromJson(Map<String, dynamic> j) =>
      ConquestProgress(
        regions: ((j['regions'] ?? []) as List)
            .map((e) => RegionProgress.fromJson(e))
            .toList(),
        totalVisited: j['totalVisited'] ?? 0,
        totalStores: j['totalStores'] ?? 0,
        overallPercent: j['overallPercent'] ?? 0,
      );
}

/// GET /api/users/me/region-progress (로그인 필요)
Future<ConquestProgress> fetchConquest() async {
  final token = AuthStore.current?.token;
  if (token == null) throw Exception('로그인이 필요합니다');
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/users/me/region-progress'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode == 200) {
    return ConquestProgress.fromJson(
        json.decode(utf8.decode(res.bodyBytes)));
  }
  final b = json.decode(utf8.decode(res.bodyBytes));
  throw Exception(b['message'] ?? '진행도를 불러오지 못했습니다');
}

// ===== 관리자: 카카오 검색 import =====

class KakaoPlace {
  final String kakaoId;
  final String placeName;
  final String address;
  final String roadAddress;
  final String phone;
  final String category;
  final String kakaoUrl;
  final double? lat;
  final double? lng;
  final String region;
  final String subRegion;
  bool alreadyAdded;

  KakaoPlace({
    required this.kakaoId,
    required this.placeName,
    required this.address,
    required this.roadAddress,
    required this.phone,
    required this.category,
    required this.kakaoUrl,
    required this.lat,
    required this.lng,
    required this.region,
    required this.subRegion,
    required this.alreadyAdded,
  });

  factory KakaoPlace.fromJson(Map<String, dynamic> j) => KakaoPlace(
        kakaoId: j['kakaoId'] ?? '',
        placeName: j['placeName'] ?? '',
        address: j['address'] ?? '',
        roadAddress: j['roadAddress'] ?? '',
        phone: j['phone'] ?? '',
        category: j['category'] ?? '',
        kakaoUrl: j['kakaoUrl'] ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        region: j['region'] ?? '기타',
        subRegion: j['subRegion'] ?? '',
        alreadyAdded: j['alreadyAdded'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'kakaoId': kakaoId,
        'placeName': placeName,
        'address': address,
        'roadAddress': roadAddress,
        'phone': phone,
        'category': category,
        'kakaoUrl': kakaoUrl,
        'lat': lat,
        'lng': lng,
        'region': region,
        'subRegion': subRegion,
        'alreadyAdded': alreadyAdded,
      };
}

class KakaoSearchResult {
  final List<KakaoPlace> results;
  final bool isEnd;
  final int totalCount;
  KakaoSearchResult(this.results, this.isEnd, this.totalCount);
}

/// GET /api/admin/search?query=...
Future<KakaoSearchResult> adminSearch(String query, {int page = 1}) async {
  final token = AuthStore.current?.token;
  final res = await http.get(
    Uri.parse('http://localhost:3000/api/admin/search')
        .replace(queryParameters: {'query': query, 'page': '$page'}),
    headers: {if (token != null) 'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) {
    final b = json.decode(utf8.decode(res.bodyBytes));
    throw Exception(b['message'] ?? '검색 실패 (${res.statusCode})');
  }
  final j = json.decode(utf8.decode(res.bodyBytes));
  return KakaoSearchResult(
    ((j['results'] ?? []) as List)
        .map((e) => KakaoPlace.fromJson(e))
        .toList(),
    j['isEnd'] ?? true,
    j['totalCount'] ?? 0,
  );
}

/// POST /api/admin/stores
Future<void> adminAddStore(KakaoPlace place) async {
  final token = AuthStore.current?.token;
  final res = await http.post(
    Uri.parse('http://localhost:3000/api/admin/stores'),
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: json.encode(place.toJson()),
  );
  if (res.statusCode == 200) return;
  final b = json.decode(utf8.decode(res.bodyBytes));
  throw Exception(b['message'] ?? '저장 실패 (${res.statusCode})');
}

/// POST /api/admin/import-bulk - 전국 주요 지역 일괄 가져오기
Future<Map<String, dynamic>> adminImportBulk() async {
  final token = AuthStore.current?.token;
  final res = await http.post(
    Uri.parse('http://localhost:3000/api/admin/import-bulk'),
    headers: {if (token != null) 'Authorization': 'Bearer $token'},
  );
  final b = json.decode(utf8.decode(res.bodyBytes));
  if (res.statusCode == 200) return b as Map<String, dynamic>;
  throw Exception(b['message'] ?? '일괄 가져오기 실패 (${res.statusCode})');
}

/// GET /api/themes/popular?limit=N - 인기 테마
Future<List<EscapeTheme>> fetchPopularThemes({int limit = 5}) async {
  final url =
      Uri.parse('http://localhost:3000/api/themes/popular?limit=$limit');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    return data.map((item) => EscapeTheme.fromJson(item)).toList();
  } else {
    throw Exception('인기 테마를 불러오지 못했습니다 (${response.statusCode})');
  }
}

/// 백엔드 API 호출: GET /api/stores/{storeId}/themes
Future<List<EscapeTheme>> fetchThemes(int storeId) async {
  final url = Uri.parse('http://localhost:3000/api/stores/$storeId/themes');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    return data.map((item) => EscapeTheme.fromJson(item)).toList();
  } else {
    throw Exception('테마 정보를 불러오지 못했습니다 (${response.statusCode})');
  }
}

/// 앱 진입점
class BangbangApp extends StatelessWidget {
  const BangbangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '모두의 방탈출',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Malgun Gothic',
        scaffoldBackgroundColor: BB.bg,
        canvasColor: BB.bg,
        colorScheme: const ColorScheme.dark(
          surface: BB.surface,
          primary: BB.neonPurple,
          secondary: BB.neonCyan,
          onSurface: BB.text,
          onPrimary: BB.bg,
          onSecondary: BB.bg,
          error: BB.neonRed,
          surfaceTint: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: BB.bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: BB.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: BB.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(BB.radius)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: BB.surface,
          selectedItemColor: BB.neonPurple,
          unselectedItemColor: BB.textDim,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: BB.surfaceHigh,
          contentTextStyle: TextStyle(color: BB.text),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: BB.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
        ),
        dividerColor: BB.border,
        iconTheme: const IconThemeData(color: BB.text),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: BB.text),
          bodySmall: TextStyle(color: BB.textDim),
          titleMedium: TextStyle(color: BB.text),
        ),
      ),
      home: const HomeMainScreen(),
    );
  }
}

/// 홈 화면 - 이제 StatefulWidget!
/// API 호출 결과를 상태로 관리해야 해서 Stateful로 바꿈
class HomeScreen extends StatefulWidget {
  /// 지역 선택 모달에서 진입 시 미리 적용할 세부지역 필터
  final String? initialSubRegion;
  const HomeScreen({super.key, this.initialSubRegion});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // API 호출 결과를 Future로 보관
  late Future<List<Store>> _storesFuture;

  // 검색/필터 상태
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  final Set<String> _selectedSubRegions = {};
  final Set<String> _selectedGenres = {};
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _storesFuture = fetchStores(); // 화면 처음 뜰 때 자동 호출
    if (widget.initialSubRegion != null &&
        widget.initialSubRegion!.isNotEmpty) {
      _selectedSubRegions.add(widget.initialSubRegion!);
      _filtersExpanded = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 검색어 + 선택된 필터 적용
  List<Store> _applyFilter(List<Store> all) {
    final q = _searchQuery.trim().toLowerCase();
    return all.where((s) {
      if (q.isNotEmpty) {
        final hay =
            '${s.name} ${s.address} ${s.subRegion} ${s.region} ${s.genre}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_selectedSubRegions.isNotEmpty &&
          !_selectedSubRegions.contains(s.subRegion)) {
        return false;
      }
      if (_selectedGenres.isNotEmpty && !_selectedGenres.contains(s.genre)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSubRegions.clear();
      _selectedGenres.clear();
    });
  }

  bool get _hasActiveFilter =>
      _searchQuery.isNotEmpty ||
      _selectedSubRegions.isNotEmpty ||
      _selectedGenres.isNotEmpty;

  /// 백엔드 API 호출: GET /api/stores
  Future<List<Store>> fetchStores() async {
    final url = Uri.parse('http://localhost:3000/api/stores');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // 한글 깨짐 방지: bodyBytes를 utf8로 디코딩
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => Store.fromJson(item)).toList();
    } else {
      throw Exception('매장 정보를 불러오지 못했습니다 (${response.statusCode})');
    }
  }

  /// 새로고침 (당겨서 또는 버튼)
  Future<void> _refresh() async {
    setState(() {
      _storesFuture = fetchStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '모두의 방탈출',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () {
              _searchFocus.requestFocus();
            },
          ),
          IconButton(
            icon: Icon(
              _filtersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            tooltip: '필터',
            onPressed: () {
              setState(() => _filtersExpanded = !_filtersExpanded);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Store>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          // 로딩 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('매장 정보 불러오는 중...'),
                ],
              ),
            );
          }
          // 에러 발생
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'API 호출 실패',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Spring Boot 서버가 켜져 있는지 확인하세요\n(http://localhost:3000)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 시도'),
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
            );
          }
          // 데이터 없음
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('매장 데이터가 없습니다'));
          }

          // 정상: 매장 리스트 표시
          final stores = snapshot.data!;
          final subRegions =
              stores.map((s) => s.subRegion).toSet().toList()..sort();
          final genres = stores.map((s) => s.genre).toSet().toList()..sort();
          final filtered = _applyFilter(stores);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                // 검색 바
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  color: BB.bg,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: BB.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '매장명, 주소, 지역, 장르 검색',
                      hintStyle: const TextStyle(color: BB.textFaint),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: BB.textDim,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: BB.textDim,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: BB.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: BB.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: BB.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: BB.neonPurple, width: 1.5),
                      ),
                    ),
                  ),
                ),
                // 필터 칩 (토글 가능)
                if (_filtersExpanded)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    color: BB.bg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterRow(
                          label: '지역',
                          options: subRegions,
                          selected: _selectedSubRegions,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 6),
                        _buildFilterRow(
                          label: '장르',
                          options: genres,
                          selected: _selectedGenres,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                // 결과 카운트 바
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: BB.bg,
                  child: Row(
                    children: [
                      Text(
                        '결과 ${filtered.length}개',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: BB.text,
                        ),
                      ),
                      if (_hasActiveFilter) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 28),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: BB.neonCyan,
                          ),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text(
                            '필터 초기화',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: _clearFilters,
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: BB.neonGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: BB.neonGreen.withOpacity(0.4),
                          ),
                        ),
                        child: const Text(
                          '● API 연결됨',
                          style: TextStyle(
                            fontSize: 10,
                            color: BB.neonGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 매장 리스트 (필터 적용)
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: BB.textFaint,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '조건에 맞는 매장이 없어요',
                                  style: TextStyle(color: BB.textDim),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _clearFilters,
                                  style: TextButton.styleFrom(
                                    foregroundColor: BB.neonCyan,
                                  ),
                                  child: const Text('필터 초기화'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final store = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StoreDetailScreen(store: store),
                                    ),
                                  );
                                },
                                borderRadius:
                                    BorderRadius.circular(BB.radius),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: BB.surface,
                                    borderRadius:
                                        BorderRadius.circular(BB.radius),
                                    border: Border.all(color: BB.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              BB.neonPurple,
                                              Color(0xFF6D28D9),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: BB.neonPurple
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              spreadRadius: -2,
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${store.id}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              store.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: BB.text,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              store.address,
                                              style: const TextStyle(
                                                color: BB.textDim,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                _buildNeonTag(
                                                  store.subRegion,
                                                  BB.neonCyan,
                                                ),
                                                const SizedBox(width: 4),
                                                _buildNeonTag(
                                                  store.genre,
                                                  BB.neonPurple,
                                                ),
                                                const SizedBox(width: 4),
                                                _buildNeonTag(
                                                  '테마 ${store.themeCount}',
                                                  BB.neonYellow,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: BB.textFaint,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const _BangbangBottomNav(currentIndex: 0),
    );
  }

  Widget _buildNeonTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFilterRow({
    required String label,
    required List<String> options,
    required Set<String> selected,
    required MaterialColor color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BB.textDim,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final isSelected = selected.contains(opt);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(opt),
                    selected: isSelected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          selected.add(opt);
                        } else {
                          selected.remove(opt);
                        }
                      });
                    },
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: isSelected ? BB.bg : BB.text,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: BB.surface,
                    selectedColor: color.shade300,
                    checkmarkColor: BB.bg,
                    side: BorderSide(
                      color: isSelected ? color.shade300 : BB.border,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 매장 상세 화면 - 매장 정보 + 테마 리스트
class StoreDetailScreen extends StatefulWidget {
  final Store store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late Future<List<EscapeTheme>> _themesFuture;
  late bool _fav;
  bool _favBusy = false;

  @override
  void initState() {
    super.initState();
    _themesFuture = fetchThemes(widget.store.id);
    _fav = FavoriteStore.has(widget.store.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _themesFuture = fetchThemes(widget.store.id);
    });
  }

  Future<void> _toggleFav() async {
    if (AuthStore.current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다 (마이 탭에서 로그인)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_favBusy) return;
    setState(() => _favBusy = true);
    try {
      final now = await FavoriteStore.toggle(widget.store.id);
      if (mounted) {
        setState(() {
          _fav = now;
          _favBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(now ? '즐겨찾기에 추가됨' : '즐겨찾기 해제됨'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _favBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          store.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _fav ? Icons.favorite : Icons.favorite_border,
              color: _fav ? BB.neonPink : null,
            ),
            onPressed: _favBusy ? null : _toggleFav,
            tooltip: '즐겨찾기',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 매장 정보 헤더 (보라 그라데이션)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A0F2E),
                  Color(0xFF2E1A4D),
                ],
              ),
              border: Border(
                bottom: BorderSide(color: BB.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: BB.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place, size: 14, color: BB.textDim),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        store.address,
                        style: const TextStyle(
                          color: BB.textDim,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDetailTag(store.subRegion, BB.neonCyan),
                    const SizedBox(width: 6),
                    _buildDetailTag(store.genre, BB.neonPurple),
                    const SizedBox(width: 6),
                    _buildDetailTag(
                      '테마 ${store.themeCount}개',
                      BB.neonYellow,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 테마 리스트
          Expanded(
            child: FutureBuilder<List<EscapeTheme>>(
              future: _themesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: BB.neonPurple),
                        SizedBox(height: 16),
                        Text(
                          '테마 정보 불러오는 중...',
                          style: TextStyle(color: BB.textDim),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 56, color: BB.neonRed),
                          const SizedBox(height: 12),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: BB.textDim),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('다시 시도'),
                            onPressed: _refresh,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BB.neonPurple,
                              foregroundColor: BB.bg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      '등록된 테마가 없습니다',
                      style: TextStyle(color: BB.textDim),
                    ),
                  );
                }

                final themes = snapshot.data!;
                return RefreshIndicator(
                  color: BB.neonPurple,
                  backgroundColor: BB.surface,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: themes.length,
                    itemBuilder: (context, index) {
                      final theme = themes[index];
                      final diffColor = theme.difficulty <= 2
                          ? BB.neonGreen
                          : theme.difficulty == 3
                              ? BB.neonYellow
                              : BB.neonPink;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ThemeDetailScreen(
                                  theme: theme,
                                  storeName: store.name,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(BB.radius),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: BB.surface,
                              borderRadius: BorderRadius.circular(BB.radius),
                              border: Border.all(color: BB.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        theme.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: BB.text,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: diffColor.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: diffColor.withOpacity(0.4),
                                        ),
                                      ),
                                      child: Text(
                                        difficultyLabel(theme.difficulty),
                                        style: TextStyle(
                                          color: diffColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  theme.description,
                                  style: const TextStyle(
                                    color: BB.textDim,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _buildDetailTag(
                                      theme.genre,
                                      BB.neonPurple,
                                    ),
                                    _buildDetailTag(
                                      '${theme.minPeople}~${theme.maxPeople}인',
                                      BB.neonCyan,
                                    ),
                                    _buildDetailTag(
                                      '${theme.durationMin}분',
                                      BB.neonGreen,
                                    ),
                                    _buildDetailTag(
                                      '${theme.price}원',
                                      BB.neonYellow,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 테마 상세 화면
class ThemeDetailScreen extends StatelessWidget {
  final EscapeTheme theme;
  final String storeName;
  const ThemeDetailScreen({
    super.key,
    required this.theme,
    this.storeName = '',
  });

  Color _difficultyColor() {
    if (theme.difficulty <= 2) return BB.neonGreen;
    if (theme.difficulty == 3) return BB.neonYellow;
    return BB.neonPink;
  }

  String _difficultyLabel() {
    switch (theme.difficulty) {
      case 1:
        return '매우 쉬움';
      case 2:
        return '쉬움';
      case 3:
        return '보통';
      case 4:
        return '어려움';
      case 5:
        return '매우 어려움';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '테마 상세',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('즐겨찾기 기능은 곧 만들 거예요!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: '즐겨찾기',
          ),
        ],
      ),
      body: ListView(
        children: [
          // 히어로 영역 (보라 네온 그라데이션)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A0F2E),
                  Color(0xFF3B1F66),
                  Color(0xFF1A0F2E),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: BB.neonPurple.withOpacity(0.3),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: BB.neonPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: BB.neonPurple.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    theme.genre,
                    style: const TextStyle(
                      color: BB.neonPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  theme.name,
                  style: const TextStyle(
                    color: BB.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (storeName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.store, color: BB.textDim, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        storeName,
                        style: const TextStyle(
                          color: BB.textDim,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 난이도 큰 배너
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BB.surface,
              borderRadius: BorderRadius.circular(BB.radius),
              border: Border.all(color: _difficultyColor().withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: _difficultyColor().withOpacity(0.18),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '난이도',
                      style: TextStyle(color: BB.textDim, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _difficultyLabel(),
                      style: TextStyle(
                        color: _difficultyColor(),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final filled = i < theme.difficulty;
                    return Container(
                      width: 14,
                      height: 24,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: filled
                            ? _difficultyColor()
                            : _difficultyColor().withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  '${theme.difficulty}/5',
                  style: TextStyle(
                    color: _difficultyColor(),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          // 정보 그리드 (인원, 시간, 가격)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _infoBox(
                    Icons.group,
                    '인원',
                    '${theme.minPeople}~${theme.maxPeople}명',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _infoBox(
                    Icons.schedule,
                    '소요시간',
                    '${theme.durationMin}분',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _infoBox(
                    Icons.payments,
                    '1인 가격',
                    '${theme.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                  ),
                ),
              ],
            ),
          ),
          // 설명
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '한 줄 설명',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: BB.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BB.surface,
                    borderRadius: BorderRadius.circular(BB.radius),
                    border: Border.all(color: BB.border),
                  ),
                  child: Text(
                    theme.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: BB.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 리뷰 섹션
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _ReviewSection(themeId: theme.id),
          ),
          // 예약 버튼 (placeholder)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.event_available),
                label: const Text(
                  '예약하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BB.neonPurple,
                  foregroundColor: BB.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BB.radius),
                  ),
                  elevation: 0,
                ).copyWith(
                  shadowColor: WidgetStateProperty.all(
                    BB.neonPurple.withOpacity(0.5),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('예약 기능은 곧 만들 거예요!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: BB.surface,
        borderRadius: BorderRadius.circular(BB.radiusS),
        border: Border.all(color: BB.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: BB.neonCyan, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: BB.textDim, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: BB.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 리뷰 섹션 위젯 =====
class _ReviewSection extends StatefulWidget {
  final int themeId;
  const _ReviewSection({required this.themeId});

  @override
  State<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<_ReviewSection> {
  late Future<ReviewList> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchReviews(widget.themeId);
  }

  void _reload() {
    setState(() => _future = fetchReviews(widget.themeId));
  }

  Future<void> _openWriteDialog() async {
    if (AuthStore.current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('리뷰 작성은 로그인이 필요합니다 (마이 탭에서 로그인)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewWriteSheet(themeId: widget.themeId),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '리뷰',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: BB.text,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openWriteDialog,
              icon: const Icon(Icons.edit, size: 15),
              label: const Text('리뷰 쓰기', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: BB.neonPurple,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<ReviewList>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: BB.neonPurple),
                ),
              );
            }
            if (snap.hasError || snap.data == null) {
              return _box(Text(
                '리뷰를 불러오지 못했어요\n${snap.error ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BB.textDim, fontSize: 13),
              ));
            }
            final data = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 평점 요약
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BB.surface,
                    borderRadius: BorderRadius.circular(BB.radius),
                    border: Border.all(color: BB.border),
                  ),
                  child: data.ratingVisible
                      ? Row(
                          children: [
                            Text(
                              data.averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: BB.neonYellow,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _stars(data.averageRating!),
                                const SizedBox(height: 4),
                                Text(
                                  '리뷰 ${data.reviewCount}개',
                                  style: const TextStyle(
                                    color: BB.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.reviews_outlined,
                                color: BB.textDim, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '리뷰 모으는 중 (${data.reviewCount}/10)\n10개 이상이면 평점이 공개돼요',
                                style: const TextStyle(
                                  color: BB.textDim,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                if (data.reviews.isEmpty)
                  _box(const Text(
                    '아직 리뷰가 없어요. 첫 리뷰를 남겨보세요!',
                    style: TextStyle(color: BB.textDim, fontSize: 13),
                  ))
                else
                  ...data.reviews.map(_reviewCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _box(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BB.surface,
          borderRadius: BorderRadius.circular(BB.radius),
          border: Border.all(color: BB.border),
        ),
        child: Center(child: child),
      );

  Widget _stars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (rating >= i + 1) {
          icon = Icons.star;
        } else if (rating >= i + 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: BB.neonYellow, size: 16);
      }),
    );
  }

  Widget _reviewCard(Review r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BB.surface,
        borderRadius: BorderRadius.circular(BB.radius),
        border: Border.all(color: BB.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                r.username,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: BB.text,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (r.isSuccess ? BB.neonGreen : BB.neonRed)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.isSuccess ? '탈출 성공' : '탈출 실패',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: r.isSuccess ? BB.neonGreen : BB.neonRed,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                r.createdAt,
                style: const TextStyle(color: BB.textFaint, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _stars(r.rating),
          const SizedBox(height: 8),
          Text(
            r.content,
            style: const TextStyle(
              color: BB.text,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 리뷰 작성 바텀시트 =====
class _ReviewWriteSheet extends StatefulWidget {
  final int themeId;
  const _ReviewWriteSheet({required this.themeId});

  @override
  State<_ReviewWriteSheet> createState() => _ReviewWriteSheetState();
}

class _ReviewWriteSheetState extends State<_ReviewWriteSheet> {
  double _rating = 3.0;
  bool _isSuccess = true;
  bool _submitting = false;
  String? _error;
  final _contentCtrl = TextEditingController();

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.length < 30) {
      setState(() => _error = '후기는 30자 이상 작성해주세요 (현재 ${content.length}자)');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await postReview(
        widget.themeId,
        rating: _rating,
        content: content,
        isSuccess: _isSuccess,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: BB.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '리뷰 쓰기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: BB.text,
            ),
          ),
          const SizedBox(height: 16),
          const Text('별점', style: TextStyle(color: BB.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final v = i + 1.0;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40),
                icon: Icon(
                  _rating >= v
                      ? Icons.star
                      : (_rating >= v - 0.5
                          ? Icons.star_half
                          : Icons.star_border),
                  color: BB.neonYellow,
                  size: 32,
                ),
                onPressed: () => setState(() => _rating = v),
              );
            })
              ..add(
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: BB.neonYellow,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
          ),
          const SizedBox(height: 16),
          const Text('탈출 결과',
              style: TextStyle(color: BB.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              _resultChip('탈출 성공', true),
              const SizedBox(width: 8),
              _resultChip('탈출 실패', false),
            ],
          ),
          const SizedBox(height: 16),
          const Text('후기 (30자 이상)',
              style: TextStyle(color: BB.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _contentCtrl,
            maxLines: 4,
            style: const TextStyle(color: BB.text, fontSize: 14),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '방탈출 경험을 공유해주세요',
              hintStyle: const TextStyle(color: BB.textFaint),
              filled: true,
              fillColor: BB.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BB.radius),
                borderSide: const BorderSide(color: BB.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BB.radius),
                borderSide: const BorderSide(color: BB.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BB.radius),
                borderSide:
                    const BorderSide(color: BB.neonPurple, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_contentCtrl.text.trim().length} / 30자',
            style: TextStyle(
              fontSize: 11,
              color: _contentCtrl.text.trim().length >= 30
                  ? BB.neonGreen
                  : BB.textFaint,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: BB.neonRed, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BB.neonPurple,
                foregroundColor: BB.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BB.radius),
                ),
                elevation: 0,
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: BB.bg,
                      ),
                    )
                  : const Text(
                      '등록',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultChip(String label, bool value) {
    final selected = _isSuccess == value;
    final color = value ? BB.neonGreen : BB.neonRed;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isSuccess = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : BB.surface,
            borderRadius: BorderRadius.circular(BB.radiusS),
            border: Border.all(
              color: selected ? color : BB.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? color : BB.textDim,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== 지도 색칠 화면 (SVG 기반) =====

/// 시도명 → 7개 권역 매핑
const Map<String, String> _provinceToRegion = {
  '서울특별시': '서울',
  '경기도': '경기·인천',
  '인천광역시': '경기·인천',
  '강원도': '강원',
  '강원특별자치도': '강원',
  '충청남도': '충청',
  '충청북도': '충청',
  '대전광역시': '충청',
  '세종특별자치시': '충청',
  '경상남도': '경상',
  '경상북도': '경상',
  '대구광역시': '경상',
  '부산광역시': '경상',
  '울산광역시': '경상',
  '전라남도': '전라',
  '전라북도': '전라',
  '전북특별자치도': '전라',
  '광주광역시': '전라',
  '제주특별자치도': '제주',
};

/// 권역 geometry: 여러 시도의 polygon ring들을 묶음
class _KoreaRegionGeom {
  final String name;
  final List<List<Offset>> rings; // 각 ring은 (lon, lat) 좌표
  _KoreaRegionGeom(this.name, this.rings);
}

/// 모든 권역의 lon/lat 범위 (프로젝션용)
class _GeoBounds {
  final double minLon, maxLon, minLat, maxLat;
  const _GeoBounds(this.minLon, this.maxLon, this.minLat, this.maxLat);

  double get aspectRatio {
    final midLat = (minLat + maxLat) / 2;
    final lonRange = (maxLon - minLon) * math.cos(midLat * math.pi / 180);
    final latRange = maxLat - minLat;
    return lonRange / latRange;
  }
}

/// 권역 라벨 anchor (실제 lat/lon)
/// 서울/경기/인천 라벨 겹침 방지하려고 수동 좌표
class _LabelAnchor {
  final String label;
  final Offset latLon; // (lon, lat)
  final bool showStats; // 매장 수 표시 여부
  const _LabelAnchor(this.label, this.latLon, {this.showStats = true});
}

const Map<String, List<_LabelAnchor>> _regionLabels = {
  '서울': [_LabelAnchor('서울', Offset(126.98, 37.55))],
  '경기·인천': [
    _LabelAnchor('경기', Offset(127.30, 37.65)),
    _LabelAnchor('인천', Offset(126.55, 37.45), showStats: false),
  ],
  '강원': [_LabelAnchor('강원', Offset(128.30, 37.85))],
  '충청': [_LabelAnchor('충청', Offset(127.20, 36.60))],
  '경상': [_LabelAnchor('경상', Offset(128.55, 36.10))],
  '전라': [_LabelAnchor('전라', Offset(126.95, 35.30))],
  '제주': [_LabelAnchor('제주', Offset(126.55, 33.40))],
};

class _KoreaGeoData {
  final List<_KoreaRegionGeom> regions;
  final _GeoBounds bounds;
  const _KoreaGeoData(this.regions, this.bounds);

  /// (lon, lat) → 위젯 좌표
  Offset project(Offset latLon, Size size) {
    final midLat = (bounds.minLat + bounds.maxLat) / 2;
    final lonRangeRaw = bounds.maxLon - bounds.minLon;
    final latRangeRaw = bounds.maxLat - bounds.minLat;
    final lonRange = lonRangeRaw * math.cos(midLat * math.pi / 180);
    final latRange = latRangeRaw;

    final mapAspect = lonRange / latRange;
    final widgetAspect = size.width / size.height;

    double drawW, drawH, offX, offY;
    if (widgetAspect > mapAspect) {
      drawH = size.height;
      drawW = drawH * mapAspect;
      offX = (size.width - drawW) / 2;
      offY = 0;
    } else {
      drawW = size.width;
      drawH = drawW / mapAspect;
      offX = 0;
      offY = (size.height - drawH) / 2;
    }

    final nx = (latLon.dx - bounds.minLon) / lonRangeRaw;
    final ny = 1 - (latLon.dy - bounds.minLat) / latRangeRaw;
    return Offset(offX + nx * drawW, offY + ny * drawH);
  }
}

/// 폐곡선의 부호 있는 면적 (절댓값이 진짜 면적)
double _ringArea(List<Offset> ring) {
  if (ring.length < 3) return 0;
  double a = 0;
  for (int i = 0; i < ring.length; i++) {
    final j = (i + 1) % ring.length;
    a += ring[i].dx * ring[j].dy - ring[j].dx * ring[i].dy;
  }
  return a.abs() / 2;
}

Future<_KoreaGeoData> loadKoreaGeoData() async {
  final raw =
      await rootBundle.loadString('assets/maps/korea_provinces.geojson');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final features = json['features'] as List;

  double minLon = double.infinity, maxLon = -double.infinity;
  double minLat = double.infinity, maxLat = -double.infinity;

  List<Offset> parseRing(List ring) {
    final pts = <Offset>[];
    for (final pt in ring) {
      final lon = (pt[0] as num).toDouble();
      final lat = (pt[1] as num).toDouble();
      pts.add(Offset(lon, lat));
    }
    return pts;
  }

  final byRegion = <String, List<List<Offset>>>{};

  for (final f in features) {
    final pname = f['properties']['name'] as String;
    final region = _provinceToRegion[pname];
    if (region == null) continue;

    final geom = f['geometry'] as Map<String, dynamic>;
    final type = geom['type'] as String;
    final coords = geom['coordinates'] as List;

    final allRings = <List<Offset>>[];
    if (type == 'Polygon') {
      for (final ring in coords) {
        allRings.add(parseRing(ring as List));
      }
    } else if (type == 'MultiPolygon') {
      for (final poly in coords) {
        for (final ring in (poly as List)) {
          allRings.add(parseRing(ring as List));
        }
      }
    }
    if (allRings.isEmpty) continue;

    // 시도별 가장 큰 ring 하나만 keep → 작은 섬 자동 제거
    allRings.sort((a, b) => _ringArea(b).compareTo(_ringArea(a)));
    final mainRing = allRings.first;

    // 다운샘플/smoothing 모두 제거 — 원본 점 그대로 사용
    // → 인접 시도 경계가 데이터 그대로 정확히 맞물림
    for (final p in mainRing) {
      if (p.dx < minLon) minLon = p.dx;
      if (p.dx > maxLon) maxLon = p.dx;
      if (p.dy < minLat) minLat = p.dy;
      if (p.dy > maxLat) maxLat = p.dy;
    }

    byRegion.putIfAbsent(region, () => []).add(mainRing);
  }

  const order = ['강원', '경상', '전라', '충청', '경기·인천', '제주', '서울'];
  final regions = order
      .where((n) => byRegion.containsKey(n))
      .map((n) => _KoreaRegionGeom(n, byRegion[n]!))
      .toList();

  return _KoreaGeoData(
    regions,
    _GeoBounds(minLon, maxLon, minLat, maxLat),
  );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum MapMode { count, rating, conquest }

class _MapScreenState extends State<MapScreen> {
  late Future<List<RegionStats>> _statsFuture;
  late Future<_KoreaGeoData> _geoFuture;
  MapMode _mode = MapMode.count;

  @override
  void initState() {
    super.initState();
    _statsFuture = fetchRegionStats();
    _geoFuture = loadKoreaGeoData();
  }

  Future<List<RegionStats>> _fetchForMode(MapMode m) {
    switch (m) {
      case MapMode.count:
        return fetchRegionStats();
      case MapMode.rating:
        return fetchRegionRating();
      case MapMode.conquest:
        return fetchRegionConquest();
    }
  }

  void _switchMode(MapMode m) {
    if (m == _mode) return;
    if (m == MapMode.conquest && AuthStore.current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('도장깨기 모드는 로그인이 필요합니다 (마이 탭)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _mode = m;
      _statsFuture = _fetchForMode(m);
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = _fetchForMode(_mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '전국 지도',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<RegionStats>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: BB.neonPurple),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: BB.neonRed),
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: BB.textDim),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BB.neonPurple,
                        foregroundColor: BB.bg,
                      ),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            );
          }

          final stats = {for (var s in snapshot.data!) s.region: s};
          return Column(
            children: [
              // 모드 토글 바
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: BB.surface,
                  border: Border(bottom: BorderSide(color: BB.border)),
                ),
                child: Row(
                  children: [
                    _modeChip('📊 매장 수', MapMode.count),
                    const SizedBox(width: 6),
                    _modeChip('⭐ 평점', MapMode.rating),
                    const SizedBox(width: 6),
                    _modeChip('🏆 도장깨기', MapMode.conquest),
                  ],
                ),
              ),
              // 인터랙티브 한국 지도 (실제 GeoJSON 기반, hover로 입체화)
              Expanded(
                child: FutureBuilder<_KoreaGeoData>(
                  future: _geoFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: BB.neonPurple,
                        ),
                      );
                    }
                    if (snap.hasError || snap.data == null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '지도 데이터 로드 실패\n${snap.error ?? ''}',
                            style: const TextStyle(color: BB.textDim),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return _InteractiveKoreaMap(
                      geo: snap.data!,
                      stats: stats,
                      onTap: (name) => _onRegionTap(name, stats[name]),
                    );
                  },
                ),
              ),
              // 범례
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: BB.surface,
                  border: Border(
                    top: BorderSide(color: BB.border),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: _legendForMode(),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const _BangbangBottomNav(currentIndex: 1),
    );
  }

  Widget _modeChip(String label, MapMode m) {
    final active = _mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(m),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? BB.neonPurple.withOpacity(0.18)
                : BB.bg,
            borderRadius: BorderRadius.circular(BB.radiusS),
            border: Border.all(
              color: active ? BB.neonPurple : BB.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? BB.neonPurple : BB.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _legendForMode() {
    switch (_mode) {
      case MapMode.count:
        return const [
          _LegendChip('S 50+', Color(0xFFC62828)),
          _LegendChip('A 30~49', Color(0xFFEF6C00)),
          _LegendChip('B 15~29', Color(0xFFF9A825)),
          _LegendChip('C 5~14', Color(0xFF9E9D24)),
          _LegendChip('D 1~4', Color(0xFFBDBDBD)),
          _LegendChip('0개', Color(0xFF757575)),
        ];
      case MapMode.rating:
        return const [
          _LegendChip('4.5+', Color(0xFF1B5E20)),
          _LegendChip('4.0+', Color(0xFF43A047)),
          _LegendChip('3.5+', Color(0xFF9E9D24)),
          _LegendChip('3.0+', Color(0xFFF9A825)),
          _LegendChip('3.0-', Color(0xFFEF6C00)),
          _LegendChip('리뷰없음', Color(0xFF757575)),
        ];
      case MapMode.conquest:
        return const [
          _LegendChip('100%', Color(0xFFA78BFA)),
          _LegendChip('81%+', Color(0xFF7C3AED)),
          _LegendChip('51%+', Color(0xFF2563EB)),
          _LegendChip('21%+', Color(0xFF3B82F6)),
          _LegendChip('1%+', Color(0xFF93C5FD)),
          _LegendChip('미정복', Color(0xFF757575)),
        ];
    }
  }

  void _onRegionTap(String regionName, RegionStats? stat) {
    if (regionName == '서울') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeoulMapScreen()),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final color = stat?.color ?? const Color(0xFF757575);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들 바
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BB.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    regionName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: BB.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${stat?.grade ?? 'NONE'}급',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '등록된 매장 ${stat?.storeCount ?? 0}개',
                style: const TextStyle(
                  fontSize: 14,
                  color: BB.textDim,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BB.surfaceHigh,
                  borderRadius: BorderRadius.circular(BB.radiusS),
                  border: Border.all(color: BB.border),
                ),
                child: Text(
                  (stat?.storeCount ?? 0) == 0
                      ? '아직 등록된 매장이 없어요. Phase 2에서 매장 데이터 확장 예정입니다.'
                      : '$regionName 지역 매장 리스트 보기는 다음 단계에서!',
                  style: const TextStyle(fontSize: 13, color: BB.textDim),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 인터랙티브 한국 지도 (CustomPaint + hover 입체화)
class _InteractiveKoreaMap extends StatefulWidget {
  final _KoreaGeoData geo;
  final Map<String, RegionStats> stats;
  final void Function(String name) onTap;
  const _InteractiveKoreaMap({
    required this.geo,
    required this.stats,
    required this.onTap,
  });

  @override
  State<_InteractiveKoreaMap> createState() => _InteractiveKoreaMapState();
}

class _InteractiveKoreaMapState extends State<_InteractiveKoreaMap> {
  String? _hovered;

  Path _buildPath(_KoreaRegionGeom region, Size size) {
    // 시도별 ring을 각각 closed path로 만든 후 union으로 묶음
    // → 내부 경계선 사라지고 권역이 하나의 외곽선으로 표시됨
    Path? combined;
    for (final ring in region.rings) {
      if (ring.isEmpty) continue;
      final p0 = widget.geo.project(ring[0], size);
      final single = Path()..moveTo(p0.dx, p0.dy);
      for (int i = 1; i < ring.length; i++) {
        final p = widget.geo.project(ring[i], size);
        single.lineTo(p.dx, p.dy);
      }
      single.close();
      combined = combined == null
          ? single
          : Path.combine(PathOperation.union, combined, single);
    }
    return combined ?? Path();
  }

  /// 작은 권역 우선 hit test (서울 → 큰 권역 순)
  String? _hitTest(Offset point, Size size) {
    final ordered = [...widget.geo.regions]..sort(
        (a, b) {
          if (a.name == '서울') return -1;
          if (b.name == '서울') return 1;
          return 0;
        },
      );
    for (final r in ordered) {
      if (_buildPath(r, size).contains(point)) return r.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return MouseRegion(
          onHover: (e) {
            final h = _hitTest(e.localPosition, size);
            if (h != _hovered) setState(() => _hovered = h);
          },
          onExit: (_) {
            if (_hovered != null) setState(() => _hovered = null);
          },
          cursor: _hovered != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final h = _hitTest(d.localPosition, size);
              if (h != null) widget.onTap(h);
            },
            child: CustomPaint(
              painter: _KoreaMapPainter(
                geo: widget.geo,
                stats: widget.stats,
                hoveredRegion: _hovered,
              ),
              size: size,
            ),
          ),
        );
      },
    );
  }
}

class _KoreaMapPainter extends CustomPainter {
  final _KoreaGeoData geo;
  final Map<String, RegionStats> stats;
  final String? hoveredRegion;

  _KoreaMapPainter({
    required this.geo,
    required this.stats,
    required this.hoveredRegion,
  });

  Path _buildPath(_KoreaRegionGeom region, Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final ring in region.rings) {
      if (ring.isEmpty) continue;
      final p0 = geo.project(ring[0], size);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < ring.length; i++) {
        final p = geo.project(ring[i], size);
        path.lineTo(p.dx, p.dy);
      }
      path.close();
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 큰 권역 → 작은 권역 (서울 마지막에 위에 그려짐)
    final ordered = [
      ...geo.regions.where((r) => r.name != hoveredRegion && r.name != '서울'),
      ...geo.regions.where((r) => r.name == '서울' && r.name != hoveredRegion),
    ];
    for (final r in ordered) {
      _drawRegion(canvas, size, r, isHovered: false);
    }
    // 호버된 권역 마지막에 (최상단)
    if (hoveredRegion != null) {
      final hov = geo.regions.firstWhere(
        (r) => r.name == hoveredRegion,
        orElse: () => geo.regions.first,
      );
      _drawRegion(canvas, size, hov, isHovered: true);
    }
  }

  void _drawRegion(
    Canvas canvas,
    Size size,
    _KoreaRegionGeom region, {
    required bool isHovered,
  }) {
    final stat = stats[region.name];
    final hasStore = (stat?.storeCount ?? 0) > 0;
    final baseColor = stat?.color ?? const Color(0xFF424258);
    final path = _buildPath(region, size);
    final bounds = path.getBounds();
    final center = bounds.center;

    canvas.save();
    if (isHovered) {
      canvas.translate(center.dx, center.dy - 6);
      canvas.scale(1.06);
      canvas.translate(-center.dx, -center.dy);

      canvas.drawShadow(path, Colors.black, 16, false);

      final glow = Paint()
        ..color = baseColor.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawPath(path, glow);
    }

    // 채우기
    canvas.drawPath(
      path,
      Paint()
        ..color = hasStore
            ? baseColor.withOpacity(isHovered ? 0.9 : 0.55)
            : (isHovered ? const Color(0xFF2D2D44) : const Color(0xFF1F1F33))
        ..style = PaintingStyle.fill,
    );

    // 보더 — 권역 외곽선 (union된 path라 내부 시도 경계는 안 그림)
    canvas.drawPath(
      path,
      Paint()
        ..color = isHovered
            ? baseColor
            : hasStore
                ? baseColor.withOpacity(0.85)
                : const Color(0xFF3A3A55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? 2.5 : 1.4
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();

    // 라벨 — anchor 지점에 그림 (스케일 영향 안 받게 restore 후 그림)
    final count = stat?.storeCount ?? 0;
    final grade = stat?.grade ?? 'NONE';
    final anchors = _regionLabels[region.name] ?? const [];
    for (final anchor in anchors) {
      final pos = geo.project(anchor.latLon, size);
      final lifted = isHovered ? pos.translate(0, -6) : pos;

      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: anchor.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isHovered ? 13 : 11,
                fontWeight: FontWeight.w800,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 4),
                ],
              ),
            ),
            if (anchor.showStats)
              TextSpan(
                text: '\n$count${grade == 'NONE' ? '' : ' · $grade'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: isHovered ? 11 : 9,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4),
                  ],
                ),
              ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(lifted.dx - tp.width / 2, lifted.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_KoreaMapPainter old) =>
      old.hoveredRegion != hoveredRegion || old.stats != stats;
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: BB.textDim),
        ),
      ],
    );
  }
}

// ===== 홈 메인 화면 (앱 진입점) =====

class HomeMainScreen extends StatefulWidget {
  const HomeMainScreen({super.key});

  @override
  State<HomeMainScreen> createState() => _HomeMainScreenState();
}

class _HomeMainScreenState extends State<HomeMainScreen> {
  late Future<List<EscapeTheme>> _popularFuture;
  late Future<List<RegionStats>> _regionFuture;

  @override
  void initState() {
    super.initState();
    _popularFuture = fetchPopularThemes(limit: 5);
    _regionFuture = fetchRegionStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _popularFuture = fetchPopularThemes(limit: 5);
      _regionFuture = fetchRegionStats();
    });
  }

  void _openList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _openRegionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BB.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const RegionPickerSheet(),
    );
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: BB.neonPurple,
        backgroundColor: BB.surface,
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // === 히어로 배너 ===
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: BB.bg,
              foregroundColor: BB.text,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: BB.text),
                  tooltip: '검색',
                  onPressed: _openList,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                title: const Text(
                  '모두의 방탈출',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/home_banner.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A0F2E),
                              Color(0xFF2E1A4D),
                              Color(0xFF0B0B14),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 하단 → bg 색으로 자연스럽게 페이드
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.55, 1.0],
                          colors: [
                            Color(0x00000000),
                            Color(0x66000000),
                            BB.bg,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === 본문 ===
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // === Bento Grid 1: 메인 액션 ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        // 좌: 큰 카드 (지도, 보라 글로우)
                        Expanded(
                          flex: 3,
                          child: _BentoCard(
                            onTap: _openMap,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF3B1F66),
                                Color(0xFF6D28D9),
                              ],
                            ),
                            glowColor: BB.neonPurple,
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(
                                    Icons.map,
                                    size: 140,
                                    color: BB.neonPurple.withOpacity(0.18),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '전국 지도',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: BB.text,
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '7개 권역',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: BB.textDim,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            '색칠된 지도로\n매장 정복 현황 보기',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: BB.text,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 우: 세로 2개 스택
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Expanded(
                                child: _BentoCard(
                                  onTap: _openRegionPicker,
                                  glowColor: BB.neonCyan,
                                  child: const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(
                                          Icons.place,
                                          color: BB.neonCyan,
                                          size: 22,
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '지역 찾기',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: BB.text,
                                              ),
                                            ),
                                            Text(
                                              '지역으로 찾기',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: BB.textDim,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: _BentoCard(
                                  onTap: _openList,
                                  glowColor: BB.neonPink,
                                  child: const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(
                                          Icons.search,
                                          color: BB.neonPink,
                                          size: 22,
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '검색',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: BB.text,
                                              ),
                                            ),
                                            Text(
                                              '이름·지역·장르',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: BB.textDim,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // === 인기 테마 ===
                _sectionHeader('🔥 인기 테마', '전체 보기', _openList),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  child: FutureBuilder<List<EscapeTheme>>(
                    future: _popularFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: BB.neonPurple,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            '${snapshot.error}',
                            style: const TextStyle(color: BB.textDim),
                          ),
                        );
                      }
                      final themes = snapshot.data ?? [];
                      if (themes.isEmpty) {
                        return const Center(
                          child: Text(
                            '테마 없음',
                            style: TextStyle(color: BB.textDim),
                          ),
                        );
                      }
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: themes.length,
                        itemBuilder: (context, index) {
                          final theme = themes[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _PopularThemeCard(theme: theme),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),

                // === 권역별 ===
                _sectionHeader('📍 권역별', '지도에서 보기', _openMap),
                const SizedBox(height: 10),
                FutureBuilder<List<RegionStats>>(
                  future: _regionFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 60,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: BB.neonPurple,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    final stats = snapshot.data!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: stats.map((s) {
                          return _RegionShortcut(
                            stat: s,
                            onTap: _openMap,
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _BangbangBottomNav(currentIndex: 0),
    );
  }

  Widget _sectionHeader(String title, String linkText, VoidCallback onLink) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: BB.text,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: BB.neonCyan,
            ),
            onPressed: onLink,
            child: Row(
              children: [
                Text(linkText, style: const TextStyle(fontSize: 12)),
                const Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 공통 Bento 카드 (다크 + 네온 글로우 보더)
class _BentoCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color glowColor;

  const _BentoCard({
    required this.child,
    required this.onTap,
    this.gradient,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BB.radius),
      child: Container(
        decoration: BoxDecoration(
          color: gradient == null ? BB.surface : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(BB.radius),
          border: Border.all(
            color: glowColor.withOpacity(0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.15),
              blurRadius: 18,
              spreadRadius: -4,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _PopularThemeCard extends StatelessWidget {
  final EscapeTheme theme;
  const _PopularThemeCard({required this.theme});

  Color _difficultyColor() {
    if (theme.difficulty <= 2) return BB.neonGreen;
    if (theme.difficulty == 3) return BB.neonYellow;
    return BB.neonPink;
  }

  @override
  Widget build(BuildContext context) {
    final diffColor = _difficultyColor();
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ThemeDetailScreen(theme: theme),
          ),
        );
      },
      borderRadius: BorderRadius.circular(BB.radius),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: BB.surface,
          borderRadius: BorderRadius.circular(BB.radius),
          border: Border.all(color: BB.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: diffColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: diffColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    difficultyLabel(theme.difficulty),
                    style: TextStyle(
                      color: diffColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: BB.neonPurple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    theme.genre,
                    style: const TextStyle(
                      color: BB.neonPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              theme.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: BB.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              theme.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: BB.textDim,
                height: 1.4,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.schedule, size: 12, color: BB.textFaint),
                const SizedBox(width: 3),
                Text(
                  '${theme.durationMin}분',
                  style: const TextStyle(fontSize: 11, color: BB.textDim),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.group, size: 12, color: BB.textFaint),
                const SizedBox(width: 3),
                Text(
                  '${theme.minPeople}~${theme.maxPeople}',
                  style: const TextStyle(fontSize: 11, color: BB.textDim),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionShortcut extends StatelessWidget {
  final RegionStats stat;
  final VoidCallback onTap;
  const _RegionShortcut({required this.stat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasStore = stat.storeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: BB.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasStore ? stat.color.withOpacity(0.6) : BB.border,
          ),
          boxShadow: hasStore
              ? [
                  BoxShadow(
                    color: stat.color.withOpacity(0.18),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: stat.color,
                shape: BoxShape.circle,
                boxShadow: hasStore
                    ? [
                        BoxShadow(
                          color: stat.color.withOpacity(0.6),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stat.region,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BB.text,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${stat.storeCount}',
              style: TextStyle(
                fontSize: 11,
                color: hasStore ? stat.color : BB.textFaint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 서울 시군구 화면 =====
// (실제 서울 SVG 추후 추가. 현재는 5x5 그리드 도식형)

const List<List<String>> _seoulGrid = [
  ['도봉', '강북', '노원', '중랑', ''],
  ['은평', '성북', '동대문', '광진', '강동'],
  ['종로', '중구', '성동', '송파', ''],
  ['마포', '용산', '서초', '강남', ''],
  ['강서', '영등포', '동작', '관악', '금천'],
];

class SeoulMapScreen extends StatelessWidget {
  const SeoulMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '서울 자치구',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: BB.surface,
              border: Border(bottom: BorderSide(color: BB.border)),
            ),
            child: Row(
              children: [
                const Text('🔍 ', style: TextStyle(fontSize: 16)),
                const Text(
                  '서울 25개 자치구',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: BB.text,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: BB.neonYellow.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: BB.neonYellow.withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    '자치구 SVG / 통계는 Phase 2',
                    style: TextStyle(
                      fontSize: 10,
                      color: BB.neonYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _seoulGrid.map((row) {
                  return Expanded(
                    child: Row(
                      children: row.map((name) {
                        if (name.isEmpty) {
                          return const Expanded(child: SizedBox());
                        }
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$name구 - 매장 리스트는 다음 단계!'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: BB.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: BB.neonCyan.withOpacity(0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: BB.neonCyan,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 즐겨찾기 화면 =====

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Future<List<Store>>? _future;

  @override
  void initState() {
    super.initState();
    if (AuthStore.current != null) {
      _future = fetchFavoriteStores();
    }
  }

  Widget _empty(IconData icon, String title, String sub, Widget? action) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: BB.surface,
                shape: BoxShape.circle,
                border: Border.all(color: BB.neonPink.withOpacity(0.3)),
              ),
              child: Icon(icon,
                  size: 56, color: BB.neonPink.withOpacity(0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: BB.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: BB.textDim,
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '즐겨찾기',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: AuthStore.current == null
          ? _empty(
              Icons.lock_outline,
              '로그인이 필요해요',
              '로그인하면 매장을 즐겨찾기 할 수 있어요',
              SizedBox(
                width: 200,
                height: 46,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('로그인 / 회원가입',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BB.neonPurple,
                    foregroundColor: BB.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BB.radius),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                    if (mounted && AuthStore.current != null) {
                      setState(() => _future = fetchFavoriteStores());
                    }
                  },
                ),
              ),
            )
          : FutureBuilder<List<Store>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: BB.neonPurple),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      '${snap.error}'.replaceFirst('Exception: ', ''),
                      style: const TextStyle(color: BB.textDim),
                    ),
                  );
                }
                final stores = snap.data ?? [];
                if (stores.isEmpty) {
                  return _empty(
                    Icons.favorite_border,
                    '아직 즐겨찾기가 없어요',
                    '매장 상세 화면에서 ♡를 눌러보세요',
                    SizedBox(
                      width: 200,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('전체 매장 보기',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BB.neonPurple,
                          foregroundColor: BB.bg,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(BB.radius),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HomeScreen(),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: stores.length,
                  itemBuilder: (context, i) {
                    final s = stores[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: BB.surface,
                        borderRadius: BorderRadius.circular(BB.radius),
                        border: Border.all(color: BB.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: const Icon(Icons.favorite,
                            color: BB.neonPink),
                        title: Text(
                          s.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: BB.text,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${s.region} · ${s.subRegion} · 테마 ${s.themeCount}',
                          style: const TextStyle(
                            color: BB.textDim,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: BB.textFaint),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StoreDetailScreen(store: s),
                            ),
                          );
                          if (mounted) {
                            setState(() =>
                                _future = fetchFavoriteStores());
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: const _BangbangBottomNav(currentIndex: 2),
    );
  }
}

// ===== 마이 페이지 =====

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  AuthUser? get _user => AuthStore.current;
  MyProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (AuthStore.current == null) {
      setState(() => _profile = null);
      return;
    }
    try {
      final p = await fetchMyProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      // 프로필 로드 실패해도 화면은 떠야 함 (칭호만 생략)
    }
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) {
      setState(() {});
      _loadProfile();
    }
  }

  Future<void> _logout() async {
    await AuthStore.clear();
    if (mounted) setState(() => _profile = null);
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = _user != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '마이',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A0F2E), Color(0xFF2E1A4D)],
              ),
              border: Border(bottom: BorderSide(color: BB.border)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: BB.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: BB.neonPurple.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    loggedIn ? Icons.person : Icons.person_outline,
                    size: 40,
                    color: loggedIn ? BB.neonPurple : BB.textDim,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        loggedIn ? _user!.nickname : '로그인이 필요합니다',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: BB.text,
                        ),
                      ),
                    ),
                    if (loggedIn && _profile != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: BB.neonPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: BB.neonPurple.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          _profile!.title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: BB.neonPurple,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  loggedIn
                      ? '@${_user!.username}'
                      : '리뷰 작성, 즐겨찾기, 도장깨기 기록을 저장하려면 로그인하세요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: BB.textDim,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: loggedIn
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text(
                            '로그아웃',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BB.textDim,
                            side: const BorderSide(color: BB.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(BB.radius),
                            ),
                          ),
                          onPressed: _logout,
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text(
                            '로그인 / 회원가입',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BB.neonPurple,
                            foregroundColor: BB.bg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(BB.radius),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _openLogin,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.rate_review_outlined,
            label: '내가 쓴 리뷰',
            onTap: () {
              if (AuthStore.current == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그인이 필요합니다'),
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyReviewsScreen(),
                ),
              );
            },
          ),
          _MenuItem(
            icon: Icons.check_circle_outline,
            label: '방문한 방',
            onTap: () {
              if (AuthStore.current == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그인이 필요합니다'),
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VisitedRoomsScreen(),
                ),
              );
            },
          ),
          _MenuItem(
            icon: Icons.emoji_events_outlined,
            label: '도장깨기 진행도',
            onTap: () {
              if (AuthStore.current == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그인이 필요합니다'),
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConquestScreen(),
                ),
              );
            },
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.info_outline,
            label: '앱 정보',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppInfoScreen(),
                ),
              );
            },
          ),
          _MenuItem(
            icon: Icons.description_outlined,
            label: '약관 / 개인정보처리방침',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsScreen(),
                ),
              );
            },
          ),
          if (AuthStore.current?.isAdmin == true) ...[
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.add_business_outlined,
              label: '관리자: 매장 추가',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAddStoreScreen(),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '방방 v0.1.0 (MVP)',
              style: TextStyle(
                fontSize: 11,
                color: BB.textFaint,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: const _BangbangBottomNav(currentIndex: 3),
    );
  }
}

// ===== 로그인 / 회원가입 화면 =====
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignup = false;
  bool _loading = false;
  String? _error;

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '아이디와 비밀번호를 입력하세요');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _isSignup
          ? await signup(username, password, _nicknameCtrl.text.trim())
          : await login(username, password);
      await AuthStore.save(user);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSignup ? '회원가입' : '로그인',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              '모두의 방탈출',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: BB.neonPurple,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            _field(_usernameCtrl, '아이디', Icons.person_outline),
            const SizedBox(height: 12),
            _field(_passwordCtrl, '비밀번호', Icons.lock_outline,
                obscure: true),
            if (_isSignup) ...[
              const SizedBox(height: 12),
              _field(_nicknameCtrl, '닉네임 (선택)', Icons.badge_outlined),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BB.neonRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(BB.radiusS),
                  border: Border.all(color: BB.neonRed.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: BB.neonRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: BB.neonRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BB.neonPurple,
                  foregroundColor: BB.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BB.radius),
                  ),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: BB.bg,
                        ),
                      )
                    : Text(
                        _isSignup ? '가입하기' : '로그인',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _isSignup = !_isSignup;
                        _error = null;
                      }),
              style: TextButton.styleFrom(foregroundColor: BB.neonCyan),
              child: Text(
                _isSignup
                    ? '이미 계정이 있나요? 로그인'
                    : '계정이 없나요? 회원가입',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: BB.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: BB.textFaint),
        prefixIcon: Icon(icon, color: BB.textDim, size: 20),
        filled: true,
        fillColor: BB.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BB.radius),
          borderSide: const BorderSide(color: BB.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BB.radius),
          borderSide: const BorderSide(color: BB.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BB.radius),
          borderSide: const BorderSide(color: BB.neonPurple, width: 1.5),
        ),
      ),
    );
  }
}

// ===== 관리자: 매장 추가 화면 =====
class AdminAddStoreScreen extends StatefulWidget {
  const AdminAddStoreScreen({super.key});

  @override
  State<AdminAddStoreScreen> createState() => _AdminAddStoreScreenState();
}

class _AdminAddStoreScreenState extends State<AdminAddStoreScreen> {
  final _ctrl = TextEditingController(text: '방탈출');
  List<KakaoPlace> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _bulkRunning = false;
  String? _error;
  int _total = 0;
  int _page = 1;
  bool _isEnd = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _bulkImport() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BB.surface,
        title: const Text('전국 일괄 가져오기',
            style: TextStyle(color: BB.text, fontSize: 16)),
        content: const Text(
          '전국 주요 지역(약 35개)의 방탈출을 카카오에서 검색해 '
          '한 번에 가져옵니다. 1~2분 걸릴 수 있어요.',
          style: TextStyle(color: BB.textDim, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: BB.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('가져오기',
                style: TextStyle(color: BB.neonPurple)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _bulkRunning = true);
    try {
      final r = await adminImportBulk();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: BB.surface,
            title: const Text('완료',
                style: TextStyle(color: BB.text, fontSize: 16)),
            content: Text(
              '신규 ${r['added']}개 추가\n'
              '중복 ${r['skipped']}개 건너뜀\n'
              '전체 매장 ${r['total']}개',
              style: const TextStyle(
                  color: BB.textDim, fontSize: 13, height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인',
                    style: TextStyle(color: BB.neonPurple)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkRunning = false);
    }
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _results = [];
    });
    try {
      final r = await adminSearch(q, page: 1);
      setState(() {
        _results = r.results;
        _total = r.totalCount;
        _isEnd = r.isEnd;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _isEnd) return;
    setState(() => _loadingMore = true);
    try {
      final r = await adminSearch(_ctrl.text.trim(), page: _page + 1);
      setState(() {
        _page += 1;
        _results = [..._results, ...r.results];
        _isEnd = r.isEnd;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _add(KakaoPlace p) async {
    try {
      await adminAddStore(p);
      setState(() => p.alreadyAdded = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${p.placeName}" 추가됨'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '관리자: 매장 추가',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          // 전국 일괄 가져오기
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                icon: _bulkRunning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: BB.bg,
                        ),
                      )
                    : const Icon(Icons.cloud_download, size: 18),
                label: Text(
                  _bulkRunning ? '가져오는 중... (1~2분)' : '전국 일괄 가져오기',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BB.neonCyan,
                  foregroundColor: BB.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BB.radius),
                  ),
                  elevation: 0,
                ),
                onPressed: _bulkRunning ? null : _bulkImport,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: BB.text),
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: '예: 홍대 방탈출, 강남 방탈출',
                      hintStyle: const TextStyle(color: BB.textFaint),
                      filled: true,
                      fillColor: BB.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(BB.radius),
                        borderSide: const BorderSide(color: BB.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(BB.radius),
                        borderSide: const BorderSide(color: BB.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(BB.radius),
                        borderSide: const BorderSide(
                            color: BB.neonPurple, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BB.neonPurple,
                      foregroundColor: BB.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BB.radius),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _loading ? null : _search,
                    child: const Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '카카오 검색 결과 $_total개 중 상위 ${_results.length}개',
                style: const TextStyle(color: BB.textDim, fontSize: 12),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: BB.neonPurple),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: BB.neonRed),
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Text(
                              '검색어를 입력하고 검색하세요',
                              style: TextStyle(color: BB.textDim),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 16),
                            itemCount: _results.length + 1,
                            itemBuilder: (context, i) {
                              if (i == _results.length) {
                                if (_isEnd) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(top: 8),
                                    child: Center(
                                      child: Text(
                                        '검색 결과 끝 (총 ${_results.length}개)',
                                        style: const TextStyle(
                                          color: BB.textFaint,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: BB.neonPurple,
                                      side: const BorderSide(
                                          color: BB.neonPurple),
                                      minimumSize:
                                          const Size.fromHeight(46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                BB.radius),
                                      ),
                                    ),
                                    onPressed:
                                        _loadingMore ? null : _loadMore,
                                    child: _loadingMore
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: BB.neonPurple,
                                            ),
                                          )
                                        : Text(
                                            '더 보기 (${_results.length}/$_total)',
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                );
                              }
                              final p = _results[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: BB.surface,
                                  borderRadius:
                                      BorderRadius.circular(BB.radius),
                                  border: Border.all(color: BB.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.placeName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: BB.text,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            p.roadAddress.isEmpty
                                                ? p.address
                                                : p.roadAddress,
                                            style: const TextStyle(
                                              color: BB.textDim,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _tag(p.region, BB.neonCyan),
                                              const SizedBox(width: 4),
                                              _tag(p.subRegion,
                                                  BB.neonPurple),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    p.alreadyAdded
                                        ? const Padding(
                                            padding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: BB.neonGreen,
                                              size: 26,
                                            ),
                                          )
                                        : ElevatedButton(
                                            style:
                                                ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  BB.neonPurple,
                                              foregroundColor: BB.bg,
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10),
                                              ),
                                              elevation: 0,
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 14,
                                                  vertical: 10),
                                            ),
                                            onPressed: () => _add(p),
                                            child: const Text(
                                              '추가',
                                              style: TextStyle(
                                                fontWeight:
                                                    FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ===== 약관 / 개인정보처리방침 화면 =====
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '약관 / 개인정보',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          bottom: const TabBar(
            labelColor: BB.neonPurple,
            unselectedLabelColor: BB.textDim,
            indicatorColor: BB.neonPurple,
            tabs: [
              Tab(text: '이용약관'),
              Tab(text: '개인정보처리방침'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TermsBody(text: _termsOfService),
            _TermsBody(text: _privacyPolicy),
          ],
        ),
      ),
    );
  }
}

class _TermsBody extends StatelessWidget {
  final String text;
  const _TermsBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BB.neonYellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(BB.radiusS),
            border: Border.all(color: BB.neonYellow.withOpacity(0.35)),
          ),
          child: const Text(
            '※ 본 문서는 MVP 단계 초안 템플릿입니다. '
            '정식 출시 전 법률 전문가 검토가 필요합니다.',
            style: TextStyle(
              fontSize: 11,
              color: BB.neonYellow,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: BB.text,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

const String _termsOfService = '''
모두의 방탈출 이용약관

시행일: 2026년 5월 18일

제1조 (목적)
본 약관은 모두의 방탈출(이하 "서비스")이 제공하는 방탈출 매장·테마 정보 조회, 리뷰 작성, 방문 기록 등 제반 서비스의 이용 조건 및 절차, 이용자와 서비스 간 권리·의무를 규정함을 목적으로 합니다.

제2조 (정의)
1. "이용자"란 본 약관에 따라 서비스를 이용하는 자를 말합니다.
2. "회원"이란 아이디와 비밀번호를 등록하여 가입한 이용자를 말합니다.
3. "콘텐츠"란 이용자가 작성한 리뷰, 별점, 방문 기록 등을 말합니다.

제3조 (약관의 효력 및 변경)
1. 본 약관은 서비스 화면에 게시함으로써 효력이 발생합니다.
2. 서비스는 관련 법령을 위반하지 않는 범위에서 약관을 변경할 수 있으며, 변경 시 적용일자 및 사유를 명시하여 사전 공지합니다.

제4조 (회원가입 및 계정)
1. 이용자는 아이디·비밀번호를 입력하여 회원으로 가입할 수 있습니다.
2. 회원은 본인의 계정 정보를 정확히 관리할 책임이 있으며, 비밀번호 관리 소홀로 인한 책임은 회원에게 있습니다.
3. 타인의 정보를 도용하거나 허위 정보를 등록한 경우 서비스 이용이 제한될 수 있습니다.

제5조 (서비스의 제공 및 변경)
1. 서비스는 매장·테마 정보, 리뷰, 지도, 도장깨기 기록 등을 제공합니다.
2. 매장·장소 정보 일부는 카카오 로컬 오픈 API를 통해 제공되며, 해당 데이터의 정확성은 원 제공처에 따릅니다.
3. 서비스 내용은 운영상·기술상 필요에 따라 변경될 수 있습니다.

제6조 (이용자의 의무)
이용자는 다음 행위를 하여서는 안 됩니다.
1. 허위 사실 또는 타인을 비방·명예훼손하는 리뷰 작성
2. 동일 콘텐츠의 반복 등록 등 서비스 운영 방해 행위
3. 타인의 계정 도용 및 부정 이용
4. 관련 법령 및 공공질서·미풍양속에 반하는 행위

제7조 (콘텐츠의 권리 및 책임)
1. 이용자가 작성한 리뷰 등 콘텐츠의 저작권은 작성자에게 있습니다.
2. 서비스는 콘텐츠를 서비스 운영·노출·홍보 목적으로 사용할 수 있습니다.
3. 이용자가 작성한 콘텐츠에 대한 책임은 작성자 본인에게 있으며, 신고 누적 시 사전 통지 없이 비공개 처리될 수 있습니다.

제8조 (면책)
1. 서비스는 천재지변, 불가항력, 이용자 귀책 사유로 인한 손해에 대하여 책임지지 않습니다.
2. 서비스는 매장 정보의 최신성·정확성을 보장하지 않으며, 실제 예약·방문은 이용자 책임 하에 이루어집니다.

제9조 (분쟁 해결)
본 약관과 관련한 분쟁은 대한민국 법령을 준거법으로 하며, 관할 법원은 민사소송법에 따릅니다.

문의: rudns10@gmail.com
''';

const String _privacyPolicy = '''
모두의 방탈출 개인정보처리방침

시행일: 2026년 5월 18일

모두의 방탈출(이하 "서비스")은 「개인정보 보호법」 등 관련 법령을 준수하며, 이용자의 개인정보를 다음과 같이 처리합니다.

1. 수집하는 개인정보 항목
- 필수: 아이디, 비밀번호(암호화 저장), 닉네임
- 서비스 이용 과정에서 생성: 작성한 리뷰·별점, 방문(클리어) 기록, 접속 토큰

2. 개인정보의 수집·이용 목적
- 회원 식별 및 로그인 인증
- 리뷰·방문 기록 등 서비스 핵심 기능 제공
- 도장깨기 진행도, 칭호 등 개인화 기능 제공
- 부정 이용 방지 및 서비스 운영·개선

3. 개인정보의 보유 및 이용 기간
- 회원 탈퇴 시 지체 없이 파기함을 원칙으로 합니다.
- 관련 법령에 따라 보존이 필요한 경우 해당 기간 동안 보관합니다.

4. 개인정보의 제3자 제공
- 서비스는 이용자의 개인정보를 외부에 제공하지 않습니다.
- 단, 법령에 의거하거나 수사기관의 적법한 요청이 있는 경우는 예외로 합니다.

5. 개인정보 처리의 위탁
- 현재 개인정보 처리를 외부에 위탁하지 않습니다.
- 장소 정보 조회를 위해 카카오 로컬 오픈 API를 이용하나, 이 과정에서 이용자의 개인정보는 전송되지 않습니다.

6. 개인정보의 파기
- 보유 기간 경과 또는 처리 목적 달성 시, 전자적 파일은 복구 불가능한 방법으로 삭제합니다.

7. 비밀번호의 보호
- 비밀번호는 단방향 암호화(BCrypt 해시)되어 저장되며, 운영자도 원문을 알 수 없습니다.

8. 이용자의 권리
- 이용자는 언제든지 본인의 개인정보 열람·정정·삭제·처리정지를 요청할 수 있습니다.
- 요청은 아래 문의처를 통해 접수할 수 있습니다.

9. 개인정보 보호책임자
- 책임자: BHAN
- 문의: rudns10@gmail.com

10. 고지의 의무
- 본 방침의 내용 추가·삭제·수정이 있을 경우 시행 전 서비스 화면을 통해 공지합니다.
''';

// ===== 앱 정보 화면 =====
class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '앱 정보',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: ListView(
        children: [
          // 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E1A4D), Color(0xFF1A0F2E)],
              ),
              border: Border(bottom: BorderSide(color: BB.border)),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: BB.neonPurple.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: BB.neonPurple.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_open,
                    size: 36,
                    color: BB.neonPurple,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '모두의 방탈출',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: BB.text,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '전국 방탈출을 정복하자\n넌 어디까지 깨봤니?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: BB.textDim,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: BB.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BB.border),
                  ),
                  child: const Text(
                    'v0.1.0 (MVP)',
                    style: TextStyle(
                      fontSize: 11,
                      color: BB.textDim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _InfoRow(label: '제작자', value: 'BHAN'),
          const _InfoDivider(),
          const _InfoRow(label: '문의', value: 'rudns10@gmail.com'),
          const _InfoDivider(),
          const _InfoRow(label: '버전', value: 'v0.1.0 (MVP)'),
          const _InfoDivider(),
          const _InfoRow(
            label: '장소 데이터',
            value: '카카오 로컬',
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '© 2026 BHAN. All rights reserved.',
              style: TextStyle(color: BB.textFaint, fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: BB.textDim,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: BB.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      color: BB.border,
      indent: 20,
      endIndent: 20,
    );
  }
}

// ===== 도장깨기 진행도 화면 =====
class ConquestScreen extends StatefulWidget {
  const ConquestScreen({super.key});

  @override
  State<ConquestScreen> createState() => _ConquestScreenState();
}

class _ConquestScreenState extends State<ConquestScreen> {
  late Future<ConquestProgress> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchConquest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '도장깨기 진행도',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: FutureBuilder<ConquestProgress>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: BB.neonPurple),
            );
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snap.error}'.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BB.textDim),
                ),
              ),
            );
          }
          final c = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 전체 요약
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E1A4D), Color(0xFF1A0F2E)],
                  ),
                  borderRadius: BorderRadius.circular(BB.radius),
                  border: Border.all(
                    color: BB.neonPurple.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      '전국 정복률',
                      style: TextStyle(
                        color: BB.textDim,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${c.overallPercent}%',
                      style: const TextStyle(
                        color: BB.neonPurple,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '방문 ${c.totalVisited} / 전체 ${c.totalStores} 매장',
                      style: const TextStyle(
                        color: BB.textDim,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: c.overallPercent / 100,
                        minHeight: 8,
                        backgroundColor: BB.surface,
                        valueColor: const AlwaysStoppedAnimation(
                            BB.neonPurple),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '권역별',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: BB.text,
                ),
              ),
              const SizedBox(height: 10),
              ...c.regions.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BB.surface,
                      borderRadius: BorderRadius.circular(BB.radius),
                      border: Border.all(color: BB.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: r.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              r.region,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: BB.text,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: r.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                r.level,
                                style: TextStyle(
                                  color: r.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${r.visitedStores}/${r.totalStores}',
                              style: const TextStyle(
                                color: BB.textDim,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: r.percent / 100,
                                  minHeight: 7,
                                  backgroundColor: BB.bg,
                                  valueColor:
                                      AlwaysStoppedAnimation(r.color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${r.percent}%',
                              style: TextStyle(
                                color: r.color,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  '리뷰를 작성하면 방문 기록이 쌓이고 정복률이 올라가요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BB.textFaint, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// ===== 방문한 방 화면 =====
class VisitedRoomsScreen extends StatefulWidget {
  const VisitedRoomsScreen({super.key});

  @override
  State<VisitedRoomsScreen> createState() => _VisitedRoomsScreenState();
}

class _VisitedRoomsScreenState extends State<VisitedRoomsScreen> {
  late Future<List<VisitedRoom>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchVisitedRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '방문한 방',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: FutureBuilder<List<VisitedRoom>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: BB.neonPurple),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snap.error}'.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BB.textDim),
                ),
              ),
            );
          }
          final rooms = snap.data ?? [];
          if (rooms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 56, color: BB.textFaint),
                  SizedBox(height: 12),
                  Text(
                    '아직 방문한 방이 없어요',
                    style: TextStyle(color: BB.textDim, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '리뷰를 작성하면 방문 기록에 추가돼요',
                    style: TextStyle(color: BB.textFaint, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          final successCount = rooms.where((r) => r.isSuccess).length;
          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0F2E), Color(0xFF2E1A4D)],
                  ),
                  borderRadius: BorderRadius.circular(BB.radius),
                  border: Border.all(color: BB.border),
                ),
                child: Row(
                  children: [
                    _stat('방문', '${rooms.length}', BB.neonCyan),
                    _divider(),
                    _stat('성공', '$successCount', BB.neonGreen),
                    _divider(),
                    _stat('실패', '${rooms.length - successCount}',
                        BB.neonRed),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: rooms.length,
                  itemBuilder: (context, i) {
                    final r = rooms[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: BB.surface,
                        borderRadius: BorderRadius.circular(BB.radius),
                        border: Border.all(color: BB.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (r.isSuccess
                                      ? BB.neonGreen
                                      : BB.neonRed)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              r.isSuccess ? Icons.check : Icons.close,
                              color:
                                  r.isSuccess ? BB.neonGreen : BB.neonRed,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.themeName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: BB.text,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.storeName} · ${r.region}',
                                  style: const TextStyle(
                                    color: BB.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            r.clearedAt,
                            style: const TextStyle(
                              color: BB.textFaint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: BB.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: BB.border,
      );
}

// ===== 내가 쓴 리뷰 화면 =====
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late Future<List<MyReview>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchMyReviews();
  }

  Widget _stars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (rating >= i + 1) {
          icon = Icons.star;
        } else if (rating >= i + 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: BB.neonYellow, size: 15);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '내가 쓴 리뷰',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: FutureBuilder<List<MyReview>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: BB.neonPurple),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snap.error}'.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BB.textDim),
                ),
              ),
            );
          }
          final reviews = snap.data ?? [];
          if (reviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rate_review_outlined,
                      size: 56, color: BB.textFaint),
                  const SizedBox(height: 12),
                  const Text(
                    '아직 작성한 리뷰가 없어요',
                    style: TextStyle(color: BB.textDim, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '테마 상세 화면에서 리뷰를 남겨보세요',
                    style: TextStyle(
                      color: BB.textFaint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, i) {
              final r = reviews[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BB.surface,
                  borderRadius: BorderRadius.circular(BB.radius),
                  border: Border.all(color: BB.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.themeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: BB.text,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (r.isSuccess ? BB.neonGreen : BB.neonRed)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.isSuccess ? '탈출 성공' : '탈출 실패',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  r.isSuccess ? BB.neonGreen : BB.neonRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _stars(r.rating),
                        const SizedBox(width: 6),
                        Text(
                          r.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: BB.neonYellow,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          r.createdAt,
                          style: const TextStyle(
                            color: BB.textFaint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.content,
                      style: const TextStyle(
                        color: BB.text,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$label"은 곧 만들 거예요'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: BB.textDim, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: BB.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: BB.neonYellow.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: BB.neonYellow.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: BB.neonYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              color: BB.textFaint,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 1,
      color: BB.border,
    );
  }
}

// ===== 공통 하단 네비게이션 =====

class _BangbangBottomNav extends StatelessWidget {
  final int currentIndex;
  const _BangbangBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: '지도'),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_border),
          label: '즐겨찾기',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: '마이',
        ),
      ],
      onTap: (index) {
        if (index == currentIndex) return;
        Widget target;
        switch (index) {
          case 0:
            target = const HomeMainScreen();
            break;
          case 1:
            target = const MapScreen();
            break;
          case 2:
            target = const FavoritesScreen();
            break;
          case 3:
            target = const MyPageScreen();
            break;
          default:
            return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => target),
        );
      },
    );
  }
}

