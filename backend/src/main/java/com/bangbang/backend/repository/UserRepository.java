package com.bangbang.backend.repository;

import com.bangbang.backend.dto.UserDto;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<UserDto, Long> {

    Optional<UserDto> findByUsername(String username);

    boolean existsByUsername(String username);

    Optional<UserDto> findByToken(String token);
}
