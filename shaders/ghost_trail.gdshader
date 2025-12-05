shader_type spatial;
// 渲染模式：
// unshaded: 不受光照影响（残影自己发光）
// blend_mix: 混合模式
// cull_disabled: 双面渲染（防止模型破面时看不到内部）
// depth_draw_always: 确保半透明排序尽可能正确
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always;

// --- 对应 CueTrail 脚本中的参数 ---
uniform vec4 albedo : source_color = vec4(0.0, 0.8, 1.0, 0.8); // 基础颜色
uniform float alpha_factor : hint_range(0.0, 1.0) = 1.0;       // 消散进度控制 (0.0 = 全透明, 1.0 = 不透明)

// --- 视觉微调参数 ---
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;      // 边缘光强度 (数值越大，中间越透明)
uniform float emission_strength : hint_range(0.0, 5.0) = 1.5;  // 发光强度 (配合 WorldEnvironment 的 Glow 使用)

void fragment() {
    // 1. 基础颜色
    vec3 base_color = albedo.rgb;

    // 2. 计算菲涅尔效应 (Fresnel)
    // NORMAL: 表面法线, VIEW: 相机视角向量
    // dot(NORMAL, VIEW) 计算夹角，边缘处接近 0，中心接近 1
    // 1.0 - dot 使得边缘变成 1，中心变成 0
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

    // 3. 应用颜色和自发光
    ALBEDO = base_color;
    EMISSION = base_color * emission_strength;

    // 4. 计算最终透明度
    // 基础透明度 * 消散因子 * 菲涅尔(让中间半透明，边缘实心)
    ALPHA = albedo.a * alpha_factor * fresnel;

    // 稍微增加一点基础不透明度，防止正对相机时完全消失
    ALPHA += (albedo.a * 0.2 * alpha_factor);

    // 钳制 Alpha 防止溢出
    ALPHA = clamp(ALPHA, 0.0, 1.0);
}