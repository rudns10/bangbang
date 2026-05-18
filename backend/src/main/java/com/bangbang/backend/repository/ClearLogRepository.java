package com.bangbang.backend.repository;

import com.bangbang.backend.dto.ClearLogDto;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ClearLogRepository extends JpaRepository<ClearLogDto, Long> {

    List<ClearLogDto> findByUserIdOrderByClearedAtDesc(Long userId);

    boolean existsByUserIdAndThemeId(Long userId, Long themeId);
}
