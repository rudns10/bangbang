package com.bangbang.backend.repository;

import com.bangbang.backend.dto.StoreDto;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Spring Data JPA가 자동으로 구현체 생성.
 * findAll, findById, save 등 기본 메서드 자동 제공.
 */
public interface StoreRepository extends JpaRepository<StoreDto, Long> {
}
