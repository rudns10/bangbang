package com.bangbang.backend.repository;

import com.bangbang.backend.dto.FavoriteDto;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FavoriteRepository extends JpaRepository<FavoriteDto, Long> {

    List<FavoriteDto> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<FavoriteDto> findByUserIdAndStoreId(Long userId, Long storeId);

    boolean existsByUserIdAndStoreId(Long userId, Long storeId);
}
