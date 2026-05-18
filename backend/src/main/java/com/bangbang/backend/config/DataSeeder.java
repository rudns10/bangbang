package com.bangbang.backend.config;

import com.bangbang.backend.dto.StoreDto;
import com.bangbang.backend.dto.ThemeDto;
import com.bangbang.backend.repository.StoreRepository;
import com.bangbang.backend.repository.ThemeRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 서버 시작 시 H2 DB가 비어있으면 더미 데이터 자동 삽입.
 * Phase 2에서 PostgreSQL + Flyway 마이그레이션으로 교체 예정.
 *
 * 매장 ID/테마 ID는 IDENTITY 전략이라 DB가 자동 할당.
 * → ThemeDto의 storeId 채울 때 매장 save 결과의 getId() 사용.
 */
@Component
public class DataSeeder implements CommandLineRunner {

    private final StoreRepository storeRepo;
    private final ThemeRepository themeRepo;

    public DataSeeder(StoreRepository storeRepo, ThemeRepository themeRepo) {
        this.storeRepo = storeRepo;
        this.themeRepo = themeRepo;
    }

    @Override
    public void run(String... args) {
        if (storeRepo.count() > 0) return;

        // === 매장 6개 ===
        StoreDto s1 = storeRepo.save(store("키이스케이프 홍대점", "서울", "홍대",
            "서울 마포구 양화로 161", "추리", 8, 37.5562, 126.9220));
        StoreDto s2 = storeRepo.save(store("마스터키 홍대점", "서울", "홍대",
            "서울 마포구 어울마당로 35", "공포", 5, 37.5538, 126.9242));
        StoreDto s3 = storeRepo.save(store("셜록홈즈 홍대점", "서울", "홍대",
            "서울 마포구 동교로 192", "추리", 6, 37.5571, 126.9258));
        StoreDto s4 = storeRepo.save(store("비트포비아 홍대점", "서울", "홍대",
            "서울 마포구 와우산로 89", "SF", 7, 37.5520, 126.9195));
        StoreDto s5 = storeRepo.save(store("넥스트에디션 합정점", "서울", "합정",
            "서울 마포구 양화로 45", "판타지", 4, 37.5494, 126.9135));
        StoreDto s6 = storeRepo.save(store("방방테스트매장", "서울", "강남",
            "서울 강남구 테헤란로 1", "추리", 3, 37.5000, 127.0000));

        // === 테마 ===
        themeRepo.saveAll(List.of(
            // 키이스케이프 홍대점 (s1) - 8개
            theme(s1.getId(), "추리의 끝", "추리", 4, 2, 4, 60, 28000, "베테랑도 어려운 본격 추리"),
            theme(s1.getId(), "우주의 비밀", "SF", 3, 2, 4, 60, 26000, "광활한 우주를 배경으로"),
            theme(s1.getId(), "마지막 편지", "감성", 2, 2, 4, 60, 25000, "눈물 보장 감성 스토리"),
            theme(s1.getId(), "어둠 속의 메시지", "공포", 5, 3, 5, 70, 30000, "심장약한 분 주의"),
            theme(s1.getId(), "타임머신", "SF", 3, 2, 4, 60, 27000, "시간을 거슬러"),
            theme(s1.getId(), "탐정사무소", "추리", 3, 2, 4, 60, 26000, "1920년대 셜록 홈즈"),
            theme(s1.getId(), "심야의 미스터리", "공포", 4, 3, 5, 65, 28000, "공포와 추리의 결합"),
            theme(s1.getId(), "황혼", "감성", 2, 2, 4, 55, 25000, "잔잔하지만 강렬한 여운"),

            // 마스터키 홍대점 (s2) - 5개
            theme(s2.getId(), "악령의 저주", "공포", 5, 3, 5, 70, 32000, "극강의 공포"),
            theme(s2.getId(), "정신병동", "공포", 4, 2, 4, 60, 28000, "심리적 공포"),
            theme(s2.getId(), "지하실", "공포", 4, 3, 5, 65, 28000, "어두컴컴한 폐쇄 공간"),
            theme(s2.getId(), "악마의 의식", "공포", 5, 4, 6, 75, 30000, "단체로 강추"),
            theme(s2.getId(), "원혼", "공포", 3, 2, 4, 55, 26000, "공포 입문자 추천"),

            // 셜록홈즈 홍대점 (s3) - 6개
            theme(s3.getId(), "베이커가 221B", "추리", 4, 2, 4, 70, 30000, "정통 셜록 홈즈"),
            theme(s3.getId(), "사라진 보석", "추리", 3, 2, 4, 60, 27000, "장난스러운 도둑"),
            theme(s3.getId(), "안개 속 살인", "추리", 4, 2, 4, 65, 28000, "런던 안개 속에서"),
            theme(s3.getId(), "암호 해독", "추리", 3, 2, 4, 60, 26000, "수학 좋아하면 강추"),
            theme(s3.getId(), "왕실의 비밀", "추리", 4, 3, 5, 70, 29000, "정치 스릴러"),
            theme(s3.getId(), "마지막 사건", "추리", 5, 2, 4, 75, 32000, "셜록 홈즈 시리즈 최종편"),

            // 비트포비아 홍대점 (s4) - 7개
            theme(s4.getId(), "인셉션", "SF", 4, 2, 4, 60, 28000, "꿈 속의 꿈"),
            theme(s4.getId(), "매트릭스", "SF", 5, 3, 5, 75, 32000, "가상현실 속 탈출"),
            theme(s4.getId(), "안드로이드", "SF", 3, 2, 4, 60, 26000, "AI와 함께"),
            theme(s4.getId(), "외계인 침공", "SF", 4, 3, 5, 70, 29000, "지구를 구해라"),
            theme(s4.getId(), "타임 패러독스", "SF", 5, 2, 4, 70, 30000, "시간 여행 머리 폭발"),
            theme(s4.getId(), "사이버 펑크", "SF", 4, 2, 4, 65, 28000, "디스토피아 미래"),
            theme(s4.getId(), "데이터 센터", "SF", 3, 2, 4, 60, 26000, "해킹 미스터리"),

            // 넥스트에디션 합정점 (s5) - 4개
            theme(s5.getId(), "마법의 숲", "판타지", 3, 2, 5, 60, 27000, "동화 같은 분위기"),
            theme(s5.getId(), "용의 보물", "판타지", 4, 3, 6, 70, 30000, "용을 물리쳐라"),
            theme(s5.getId(), "마녀의 성", "판타지", 4, 2, 4, 65, 28000, "마법 학교 분위기"),
            theme(s5.getId(), "엘프의 비밀", "판타지", 3, 2, 4, 60, 26000, "신비로운 엘프 마을"),

            // 방방테스트매장 (s6) - 3개
            theme(s6.getId(), "강남 1번가", "추리", 3, 2, 4, 60, 28000, "강남 테헤란로의 비밀"),
            theme(s6.getId(), "지하 라운지", "추리", 4, 2, 4, 65, 30000, "심야의 음모"),
            theme(s6.getId(), "트레이딩룸", "추리", 5, 3, 5, 70, 32000, "월스트리트 스타일")
        ));

        System.out.println("=== DataSeeder: 매장 " + storeRepo.count()
            + "개, 테마 " + themeRepo.count() + "개 시드 완료 ===");
    }

    private static StoreDto store(String name, String region, String subRegion,
        String address, String genre, int themeCount, double lat, double lng) {
        StoreDto s = new StoreDto();
        s.setName(name);
        s.setRegion(region);
        s.setSubRegion(subRegion);
        s.setAddress(address);
        s.setGenre(genre);
        s.setThemeCount(themeCount);
        s.setLatitude(lat);
        s.setLongitude(lng);
        return s;
    }

    private static ThemeDto theme(Long storeId, String name, String genre,
        int difficulty, int minPeople, int maxPeople, int durationMin,
        int price, String description) {
        ThemeDto t = new ThemeDto();
        t.setStoreId(storeId);
        t.setName(name);
        t.setGenre(genre);
        t.setDifficulty(difficulty);
        t.setMinPeople(minPeople);
        t.setMaxPeople(maxPeople);
        t.setDurationMin(durationMin);
        t.setPrice(price);
        t.setDescription(description);
        return t;
    }
}
