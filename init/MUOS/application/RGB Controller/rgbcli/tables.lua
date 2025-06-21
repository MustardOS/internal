-- tables.lua

local tables = {}

tables.modes = {
    "Off",                   
    "Static", 
    "Fast Breathing", 
    "Med Breathing", 
    "Slow Breathing",
    "Static Combo",
    "Mono Rainbow", 
    "Multi Rainbow"
}

tables.colors = {
    {name = "Red", rgb = {255, 0, 0}},
    {name = "Hot Pink", rgb = {255, 20, 40}},
    {name = "Pink", rgb = {190, 18, 80}},
    {name = "Blossom", rgb = {255, 119, 168}},
    {name = "Peach", rgb = {255, 157, 129}},  
    {name = "Pastel Orange", rgb = {210, 105, 30}},       
    {name = "Salmon", rgb = {171, 82, 54}},
    {name = "Light Orange", rgb = {255, 87, 34}},
    {name = "Orange", rgb = {255, 130, 0}},
    {name = "Mustard", rgb = {225, 173, 1}},
    {name = "Yellow", rgb = {255, 255, 0}},  
    {name = "Olive", rgb = {128, 128, 0}}, 
    {name = "Vanilla", rgb = {255, 236, 39}}, 
    {name = "Lime Green", rgb = {168, 231, 46}},   
    {name = "Pistachio", rgb = {50, 255, 50}},
    {name = "Green", rgb = {0, 255, 0}},
    {name = "Neon Green", rgb = {0, 228, 54}},
    {name = "Neon Cyan", rgb = {0, 255, 255}},           
    {name = "Light Blue", rgb = {64, 224, 208}},      
    {name = "Sky Blue", rgb = {135, 206, 235}},   
    {name = "Blue", rgb = {41, 173, 255}},
    {name = "True Blue", rgb = {0, 0, 255}},          
    {name = "Neon Purple", rgb = {128, 0, 255}},
    {name = "Purple", rgb = {160, 32, 240}},      
    {name = "Lavender", rgb = {131, 70, 156}},
    {name = "White", rgb = {255, 255, 255}},     
}

tables.double_colors = {
    {name = "Switch", rgb = {255, 0, 0, 0, 0, 255}}, 
    {name = "Moo", rgb = {0, 0, 0, 255, 241, 232}},    
    {name = "Melon", rgb = {255, 0, 5, 0, 255, 0}}, 
    {name = "Neon", rgb = {255, 0, 30, 0, 228, 54}},
	{name = "Tropical", rgb = {255, 69, 0, 0, 255, 0}},
    {name = "Cotton Candy", rgb = {255, 236, 39, 255, 119, 168}}

}

tables.settings = {
    mode = 1,         -- Off mode initially
    color = 5,        -- Default color
    combo = 1,
    brightness = 7,   -- Scale of 1 to 10
    speed = 2  -- Default speed (scale 1 to 10)
}

return tables
