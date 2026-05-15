import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

void main() {
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
      title: '방방',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4E79),
        ),
        useMaterial3: true,
        fontFamily: 'Malgun Gothic',
      ),
      home: const HomeScreen(),
    );
  }
}

/// 홈 화면 - 이제 StatefulWidget!
/// API 호출 결과를 상태로 관리해야 해서 Stateful로 바꿈
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // API 호출 결과를 Future로 보관
  late Future<List<Store>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = fetchStores(); // 화면 처음 뜰 때 자동 호출
  }

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
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        title: const Text(
          '방방',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('검색 기능은 곧 만들 거예요!'),
                  duration: Duration(seconds: 1),
                ),
              );
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
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                // 상단 정보 바
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      const Text('📍 ', style: TextStyle(fontSize: 18)),
                      const Text(
                        '홍대 인근',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· 총 ${stores.length}개 매장',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🟢 API 연결됨',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 매장 리스트
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: stores.length,
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1F4E79),
                            child: Text(
                              '${store.id}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            store.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  store.address,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildTag(store.subRegion, Colors.blue),
                                    const SizedBox(width: 4),
                                    _buildTag(store.genre, Colors.green),
                                    const SizedBox(width: 4),
                                    _buildTag(
                                      '테마 ${store.themeCount}개',
                                      Colors.orange,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoreDetailScreen(store: store),
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
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1F4E79),
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '리스트'),
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
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          } else if (index >= 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('해당 탭은 곧 만들 거예요!'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildTag(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
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

  @override
  void initState() {
    super.initState();
    _themesFuture = fetchThemes(widget.store.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _themesFuture = fetchThemes(widget.store.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        title: Text(
          store.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 매장 정보 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        store.address,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildHeaderTag(store.subRegion, Colors.blue),
                    const SizedBox(width: 4),
                    _buildHeaderTag(store.genre, Colors.green),
                    const SizedBox(width: 4),
                    _buildHeaderTag('테마 ${store.themeCount}개', Colors.orange),
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
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('테마 정보 불러오는 중...'),
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
                              size: 56, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
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
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('등록된 테마가 없습니다'));
                }

                final themes = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: themes.length,
                    itemBuilder: (context, index) {
                      final theme = themes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  theme.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                '★' * theme.difficulty +
                                    '☆' * (5 - theme.difficulty),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  theme.description,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _buildHeaderTag(theme.genre, Colors.purple),
                                    _buildHeaderTag(
                                      '${theme.minPeople}~${theme.maxPeople}인',
                                      Colors.blue,
                                    ),
                                    _buildHeaderTag(
                                      '${theme.durationMin}분',
                                      Colors.teal,
                                    ),
                                    _buildHeaderTag(
                                      '${theme.price}원',
                                      Colors.orange,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
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

  Widget _buildHeaderTag(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color.shade800,
          fontWeight: FontWeight.w500,
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
    required this.storeName,
  });

  Color _difficultyColor() {
    if (theme.difficulty <= 2) return Colors.green;
    if (theme.difficulty == 3) return Colors.orange;
    return Colors.red;
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
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        title: const Text(
          '테마 상세',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
          // 히어로 영역 (테마명 + 매장)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F4E79), Color(0xFF2E6BA5)],
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    theme.genre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  theme.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.store, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      storeName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 난이도 큰 배너
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _difficultyColor().withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _difficultyColor().withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '난이도',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _difficultyLabel(),
                      style: TextStyle(
                        color: _difficultyColor(),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '★' * theme.difficulty + '☆' * (5 - theme.difficulty),
                  style: TextStyle(
                    color: _difficultyColor(),
                    fontSize: 22,
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    theme.description,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          // 리뷰 자리 (placeholder)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '리뷰',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Coming soon',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '리뷰 기능은 다음 단계에서!',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 예약 버튼 (placeholder)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.event_available),
                label: const Text(
                  '예약하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1F4E79), size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 지도 색칠 화면 (SVG 기반) =====

/// 권역 배지 배치 정보 — SVG 컨테이너 대비 비율 좌표 (0~1)
/// 실제 한국 지리 위치 근사
class _RegionAnchor {
  final String name;
  final double cx; // 중심 x (비율)
  final double cy; // 중심 y (비율)
  const _RegionAnchor(this.name, this.cx, this.cy);
}

const List<_RegionAnchor> _regionAnchors = [
  _RegionAnchor('강원',     0.62, 0.20),
  _RegionAnchor('경기·인천', 0.36, 0.24),
  _RegionAnchor('서울',     0.40, 0.18),
  _RegionAnchor('충청',     0.42, 0.40),
  _RegionAnchor('전라',     0.32, 0.62),
  _RegionAnchor('경상',     0.62, 0.52),
  _RegionAnchor('제주',     0.28, 0.92),
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<List<RegionStats>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = fetchRegionStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = fetchRegionStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        title: const Text(
          '전국 지도',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
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
              // 모드 바
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    const Text('📊 ', style: TextStyle(fontSize: 16)),
                    const Text(
                      '매장 수 모드',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '평점/도장깨기 모드는 Phase 2',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 지도 영역
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // SVG의 viewBox 비율: 1771 x 1672 ≈ 1.06
                    const svgAspect = 1771.627 / 1672.414;
                    double w = constraints.maxWidth * 0.95;
                    double h = w / svgAspect;
                    if (h > constraints.maxHeight * 0.95) {
                      h = constraints.maxHeight * 0.95;
                      w = h * svgAspect;
                    }
                    return Center(
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: Stack(
                          children: [
                            // 배경: 실제 한국 지도 SVG
                            Positioned.fill(
                              child: SvgPicture.asset(
                                'assets/maps/south_korea.svg',
                                fit: BoxFit.contain,
                                placeholderBuilder: (_) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                            // 오버레이: 각 권역 배지
                            ..._regionAnchors.map((anchor) {
                              final stat = stats[anchor.name];
                              final color =
                                  stat?.color ?? const Color(0xFF757575);
                              final count = stat?.storeCount ?? 0;
                              final grade = stat?.grade ?? 'NONE';
                              // 배지 크기는 매장 수에 따라 약간 변화
                              final badgeSize = 56.0 + (count > 0 ? 6.0 : 0.0);
                              return Positioned(
                                left: anchor.cx * w - badgeSize / 2,
                                top: anchor.cy * h - badgeSize / 2,
                                width: badgeSize,
                                height: badgeSize,
                                child: GestureDetector(
                                  onTap: () => _onRegionTap(anchor.name, stat),
                                  child: _RegionBadge(
                                    name: anchor.name,
                                    count: count,
                                    grade: grade,
                                    color: color,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 범례
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.shade50,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: const [
                    _LegendChip('S 50+', Color(0xFFC62828)),
                    _LegendChip('A 30~49', Color(0xFFEF6C00)),
                    _LegendChip('B 15~29', Color(0xFFF9A825)),
                    _LegendChip('C 5~14', Color(0xFF9E9D24)),
                    _LegendChip('D 1~4', Color(0xFFBDBDBD)),
                    _LegendChip('0개', Color(0xFF757575)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
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
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: stat?.color ?? Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    regionName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${stat?.grade ?? 'NONE'}급',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '등록된 매장 ${stat?.storeCount ?? 0}개',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (stat?.storeCount ?? 0) == 0
                      ? '아직 등록된 매장이 없어요. Phase 2에서 매장 데이터 확장 예정입니다.'
                      : '$regionName 지역 매장 리스트 보기는 다음 단계에서!',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RegionBadge extends StatelessWidget {
  final String name;
  final int count;
  final String grade;
  final Color color;
  const _RegionBadge({
    required this.name,
    required this.count,
    required this.grade,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 2),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            grade == 'NONE' ? '-' : grade,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
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
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
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
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        title: const Text(
          '서울 자치구',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('🔍 ', style: TextStyle(fontSize: 16)),
                const Text(
                  '서울 25개 자치구',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '자치구 SVG / 통계는 Phase 2',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber.shade900,
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
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
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

