package com.bangbang.backend.controller;

import com.bangbang.backend.dto.AuthDto.ErrorResponse;
import com.bangbang.backend.dto.FavoriteDto;
import com.bangbang.backend.dto.StoreDto;
import com.bangbang.backend.dto.UserDto;
import com.bangbang.backend.repository.FavoriteRepository;
import com.bangbang.backend.repository.StoreRepository;
import com.bangbang.backend.repository.UserRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/favorites")
public class FavoriteController {

    private final FavoriteRepository favoriteRepository;
    private final StoreRepository storeRepository;
    private final UserRepository userRepository;

    public FavoriteController(FavoriteRepository favoriteRepository,
                              StoreRepository storeRepository,
                              UserRepository userRepository) {
        this.favoriteRepository = favoriteRepository;
        this.storeRepository = storeRepository;
        this.userRepository = userRepository;
    }

    private UserDto userFromAuth(String auth) {
        if (auth == null || auth.isBlank()) return null;
        String token = auth.startsWith("Bearer ") ? auth.substring(7) : auth;
        return userRepository.findByToken(token).orElse(null);
    }

    // GET /api/favorites - 내 즐겨찾기 매장 목록 (매장 정보 포함)
    @GetMapping
    public ResponseEntity<?> myFavorites(
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        UserDto user = userFromAuth(auth);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("로그인이 필요합니다"));
        }
        List<StoreDto> stores = favoriteRepository
            .findByUserIdOrderByCreatedAtDesc(user.getId())
            .stream()
            .map(f -> storeRepository.findById(f.getStoreId()).orElse(null))
            .filter(s -> s != null)
            .toList();
        return ResponseEntity.ok(stores);
    }

    // GET /api/favorites/ids - 내 즐겨찾기 매장 ID 목록 (♡ 상태 표시용)
    @GetMapping("/ids")
    public ResponseEntity<?> myFavoriteIds(
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        UserDto user = userFromAuth(auth);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("로그인이 필요합니다"));
        }
        List<Long> ids = favoriteRepository
            .findByUserIdOrderByCreatedAtDesc(user.getId())
            .stream()
            .map(FavoriteDto::getStoreId)
            .toList();
        return ResponseEntity.ok(Map.of("storeIds", ids));
    }

    // POST /api/favorites/{storeId} - 즐겨찾기 추가
    @PostMapping("/{storeId}")
    public ResponseEntity<?> add(
        @PathVariable Long storeId,
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        UserDto user = userFromAuth(auth);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("로그인이 필요합니다"));
        }
        if (!favoriteRepository
                .existsByUserIdAndStoreId(user.getId(), storeId)) {
            FavoriteDto f = new FavoriteDto();
            f.setUserId(user.getId());
            f.setStoreId(storeId);
            f.setCreatedAt(LocalDateTime.now());
            favoriteRepository.save(f);
        }
        return ResponseEntity.ok(Map.of("favorited", true));
    }

    // DELETE /api/favorites/{storeId} - 즐겨찾기 해제
    @DeleteMapping("/{storeId}")
    public ResponseEntity<?> remove(
        @PathVariable Long storeId,
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        UserDto user = userFromAuth(auth);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("로그인이 필요합니다"));
        }
        favoriteRepository
            .findByUserIdAndStoreId(user.getId(), storeId)
            .ifPresent(favoriteRepository::delete);
        return ResponseEntity.ok(Map.of("favorited", false));
    }
}
