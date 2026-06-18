<?php

namespace Database\Factories;

use App\Models\Project;
use Illuminate\Database\Eloquent\Factories\Factory;

class ProjectFactory extends Factory
{
    public function definition(): array
    {
        return [
            'title' => fake()->sentence(6),
            'category' => '科技项目',
            'project_type' => '重点扶持',
            'status' => Project::STATUS_DRAFT,
            'summary' => fake()->paragraph(),
            'budget_amount' => fake()->randomFloat(2, 10000, 500000),
        ];
    }
}

