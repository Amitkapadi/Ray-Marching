
inline float SphereDistance(float3 position, float4 posNsize, float4 reps) {

	return length(frac((position - posNsize.xyz + reps.y)* reps.z) * reps.x - reps.y) - posNsize.w;
}

inline float CubeDistance(float3 p, float4 posNsize, float3 size, float softness) {

	p -= posNsize.xyz;

	float3 q = abs(p) - size;

	float dist = length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - softness;

	return dist;
}

inline float Mix(float a, float b, float p) {
	return a * (1 - p) + b * p;
}

inline float CubicSmin(float a, float b, float k)
{
	float h = max(k - abs(a - b), 0.0) / (k + 0.0001);
	return min(a, b) - h * h*h*k*(1.0 / 6.0);
}

inline float OpSmoothSubtraction(float d1, float d2, float k) {

	float h = saturate((1 - (d2 + d1) / (k + 0.0001))*0.5);

	return Mix(d1, -d2, h) + k * h * (1 - h);

}

inline float DifferenceSDF(float distA, float distB) {
	return max(distA, -distB);
}
