package com.bangbang.backend.dto;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 즐겨찾기 (매장 단위). (userId, storeId) 유니크.
 */
@Entity
@Table(
    name = "favorite",
    uniqueConstraints = @UniqueConstraint(columnNames = {"userId", "storeId"})
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class FavoriteDto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long userId;
    private Long storeId;
    private LocalDateTime createdAt;
}
