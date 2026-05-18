package com.bangbang.backend.controller;

import com.bangbang.backend.dto.StoreDto;
import com.bangbang.backend.repository.StoreRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/stores")
public class StoreController {

    private final StoreRepository storeRepository;

    public StoreController(StoreRepository storeRepository) {
        this.storeRepository = storeRepository;
    }

    @GetMapping
    public List<StoreDto> getAllStores() {
        return storeRepository.findAll();
    }

    @GetMapping("/{id}")
    public StoreDto getStoreById(@PathVariable Long id) {
        return storeRepository.findById(id).orElse(null);
    }
}
