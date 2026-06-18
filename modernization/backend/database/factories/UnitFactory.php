<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;

class UnitFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->company(),
            'credit_code' => strtoupper(fake()->bothify('########????????')), 
            'contact_name' => fake()->name(),
            'contact_mobile' => fake()->phoneNumber(),
            'email' => fake()->safeEmail(),
            'address' => fake()->address(),
            'status' => 'active',
        ];
    }
}

