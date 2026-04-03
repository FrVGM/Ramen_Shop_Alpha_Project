shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.0, 1.0); // Amarillo
uniform float speed : hint_range(0.1, 10.0) = 3.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// 1. Obtenemos la textura y el color del botón (el gris que pusiste en el inspector)
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	
	// 2. Pulso suave
	float pulse = (sin(TIME * speed) + 1.0) * 0.5;
	
	// 3. Aplicamos el brillo solo a los bordes o áreas visibles (usando el alfa)
	// Mezclamos el color base con el color de brillo según el pulso
	vec3 glowing_layer = mix(base_color.rgb, glow_color.rgb, pulse * intensity);
	
	// 4. IMPORTANTE: Mantenemos la transparencia original (tu gris semitransparente)
	COLOR = vec4(glowing_layer, base_color.a);
}
