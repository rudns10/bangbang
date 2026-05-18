package com.bangbang.backend.repository;

import com.bangbang.backend.dto.ReviewDto;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReviewRepository extends JpaRepository<ReviewDto, Long> {

    List<ReviewDto> findByThemeIdOrderByCreatedAtDesc(Long themeId);

    List<ReviewDto> findByUserIdOrderByCreatedAtDesc(Long userId);

    boolean existsByThemeIdAndUserId(Long themeId, Long userId);

    long countByThemeId(Long themeId);
}
