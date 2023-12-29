/**
 * X17R algorithm (X17 with Randomized chain order)
 *
 * tpruvot 2018 - GPL code
 * Copyright (c) 2020 XpsCommunity team
 */

#include <stdio.h>
#include <memory.h>
#include <unistd.h>

extern "C" {
#include "sph/sph_blake.h"
#include "sph/sph_bmw.h"
#include "sph/sph_groestl.h"
#include "sph/sph_skein.h"
#include "sph/sph_jh.h"
#include "sph/sph_keccak.h"

#include "sph/sph_luffa.h"
#include "sph/sph_cubehash.h"
#include "sph/sph_shavite.h"
#include "sph/sph_simd.h"
#include "sph/sph_echo.h"

#include "sph/sph_hamsi.h"
#include "sph/sph_fugue.h"
#include "sph/sph_shabal.h"
#include "sph/sph_whirlpool.h"
#include "sph/sph_sha2.h"
#include "sph/sph_haval.h"
}

#include "miner.h"
#include "cuda_helper.h"
#include "cuda_x17.h"

static uint32_t *d_hash[MAX_GPUS];

enum Algo {
	BLAKE = 0,
	BMW,
	GROESTL,
	JH,
	KECCAK,
	SKEIN,
	LUFFA,
	CUBEHASH,
	SHAVITE,
	SIMD,
	ECHO,
	HAMSI,
	FUGUE,
	SHABAL,
	WHIRLPOOL,
	SHA512,
	HAVAL,
	HASH_FUNC_COUNT
};

static const char* algo_strings[] = {
	"blake",
	"bmw512",
	"groestl",
	"jh512",
	"keccak",
	"skein",
	"luffa",
	"cube",
	"shavite",
	"simd",
	"echo",
	"hamsi",
	"fugue",
	"shabal",
	"whirlpool",
	"sha512",
	"haval256",
	NULL
};

static __thread uint32_t s_ntime = UINT32_MAX;
static __thread bool s_implemented = false;
static __thread char hashOrder[HASH_FUNC_COUNT + 1] = { 0 };
static __thread bool x17_context_init = false;

static void getAlgoString(const uint32_t* prevblock, char *output)
{
	char *sptr = output;
	uint8_t* data = (uint8_t*)prevblock;

	for (uint8_t j = 0; j < HASH_FUNC_COUNT; j++) {
		//uint8_t b = (15 - j) >> 1; // 16 ascii hex chars, reversed
		//uint8_t algoDigit = (j & 1) ? data[b] & 0xF : data[b] >> 4;
		uint8_t algoDigit = data[j] % HASH_FUNC_COUNT;
		if (algoDigit >= 10)
			sprintf(sptr, "%c", 'A' + (algoDigit - 10));
		else
			sprintf(sptr, "%u", (uint32_t) algoDigit);
		sptr++;
	}
	*sptr = '\0';
}


struct x17_contexts
{
	sph_blake512_context ctx_blake;
	sph_bmw512_context ctx_bmw;
	sph_groestl512_context ctx_groestl;
	sph_jh512_context ctx_jh;
	sph_keccak512_context ctx_keccak;
	sph_skein512_context ctx_skein;
	sph_luffa512_context ctx_luffa;
	sph_cubehash512_context ctx_cubehash;
	sph_shavite512_context ctx_shavite;
	sph_simd512_context ctx_simd;
	sph_echo512_context ctx_echo;
	sph_hamsi512_context ctx_hamsi;
	sph_fugue512_context ctx_fugue;
	sph_shabal512_context ctx_shabal;
	sph_whirlpool_context ctx_whirlpool;
	sph_sha512_context ctx_sha512;
	sph_haval256_5_context ctx_haval;
};

static __thread x17_contexts base_contexts;

static void init_contexts(x17_contexts *ctx)
{
	sph_blake512_init(&ctx->ctx_blake);
	sph_bmw512_init(&ctx->ctx_bmw);
	sph_groestl512_init(&ctx->ctx_groestl);
	sph_skein512_init(&ctx->ctx_skein);
	sph_jh512_init(&ctx->ctx_jh);
	sph_keccak512_init(&ctx->ctx_keccak);
	sph_luffa512_init(&ctx->ctx_luffa);
	sph_cubehash512_init(&ctx->ctx_cubehash);
	sph_shavite512_init(&ctx->ctx_shavite);
	sph_simd512_init(&ctx->ctx_simd);
	sph_echo512_init(&ctx->ctx_echo);
	sph_hamsi512_init(&ctx->ctx_hamsi);
	sph_fugue512_init(&ctx->ctx_fugue);
	sph_shabal512_init(&ctx->ctx_shabal);
	sph_whirlpool_init(&ctx->ctx_whirlpool);
	sph_sha512_init(&ctx->ctx_sha512);
	sph_haval256_5_init(&ctx->ctx_haval);
}


// X17R CPU Hash (Validation)
extern "C" void x17_hash(void *output, const void *input)
{
	unsigned char _ALIGN(64) hash[128];

	

	void *in = (void*) input;
	int size = 80;

	uint32_t *in32 = (uint32_t*) input;
	getAlgoString(&in32[1], hashOrder);
	//applog(LOG_INFO, "hashOrder %s ", hashOrder);
	memset(&hash, 0, 128);
	x17_contexts ctx;
	if (!x17_context_init) {
		init_contexts(&base_contexts);
		x17_context_init = true;
	}
	memcpy(&ctx, &base_contexts, sizeof(x17_contexts));
	

	
	sph_blake512(&ctx.ctx_blake, in, size);
	sph_blake512_close(&ctx.ctx_blake, hash);

	size = 64;
	
	sph_bmw512(&ctx.ctx_bmw, hash, size);
	sph_bmw512_close(&ctx.ctx_bmw, hash);

	
	sph_groestl512(&ctx.ctx_groestl, hash, size);
	sph_groestl512_close(&ctx.ctx_groestl, hash);

	
	sph_skein512(&ctx.ctx_skein, hash, size);
	sph_skein512_close(&ctx.ctx_skein, hash);

	
	sph_jh512(&ctx.ctx_jh, hash, size);
	sph_jh512_close(&ctx.ctx_jh, hash);

	
	sph_keccak512(&ctx.ctx_keccak, hash, size);
	sph_keccak512_close(&ctx.ctx_keccak, hash);

	
	sph_luffa512(&ctx.ctx_luffa, hash, size);
	sph_luffa512_close(&ctx.ctx_luffa, hash);

	
	sph_cubehash512(&ctx.ctx_cubehash, hash, size);
	sph_cubehash512_close(&ctx.ctx_cubehash, hash);


	
	sph_shavite512(&ctx.ctx_shavite, hash, size);
	sph_shavite512_close(&ctx.ctx_shavite, hash);

	
	sph_simd512(&ctx.ctx_simd, hash, size);
	sph_simd512_close(&ctx.ctx_simd, hash);

	
	sph_echo512(&ctx.ctx_echo, hash, size);
	sph_echo512_close(&ctx.ctx_echo, hash);

	
	sph_hamsi512(&ctx.ctx_hamsi, hash, size);
	sph_hamsi512_close(&ctx.ctx_hamsi, hash);


	
	sph_fugue512(&ctx.ctx_fugue, hash, size);
	sph_fugue512_close(&ctx.ctx_fugue, hash);


	
	sph_shabal512(&ctx.ctx_shabal, hash, size);
	sph_shabal512_close(&ctx.ctx_shabal, hash);

	
	sph_whirlpool(&ctx.ctx_whirlpool, hash, size);
	sph_whirlpool_close(&ctx.ctx_whirlpool, hash);


	
	sph_sha512(&ctx.ctx_sha512,(const void*) hash, size);
	sph_sha512_close(&ctx.ctx_sha512,(void*) hash);

	
	sph_haval256_5(&ctx.ctx_haval, (const void*)hash, size);
	sph_haval256_5_close(&ctx.ctx_haval, hash);

	memcpy(output, hash, 32);
}

static bool init[MAX_GPUS] = { 0 };

//#define _DEBUG
#define _DEBUG_PREFIX "x17-"
#include "cuda_debug.cuh"

//static int algo80_tests[HASH_FUNC_COUNT] = { 0 };
//static int algo64_tests[HASH_FUNC_COUNT] = { 0 };
static int algo80_fails[HASH_FUNC_COUNT] = { 0 };

extern "C" int scanhash_x17(int thr_id, struct work* work, uint32_t max_nonce, unsigned long *hashes_done)
{
	uint32_t *pdata = work->data;
	uint32_t *ptarget = work->target;
	const uint32_t first_nonce = pdata[19];
	const int dev_id = device_map[thr_id];
	
	//int intensity = (device_sm[dev_id] > 500 && !is_windows()) ? 20 : 19;
	//if (strstr(device_name[dev_id], "GTX 1080")) intensity = 20;
	//uint32_t throughput = cuda_default_throughput(thr_id, 1U << intensity);
	//if (init[thr_id]) throughput = min(throughput, max_nonce - first_nonce);

	uint32_t default_throughput = 1 << 20;
	if ((strstr(device_name[dev_id], "1050")))
	{
		default_throughput = 1 << 20;
	}
	else if ((strstr(device_name[dev_id], "950")))
	{
		default_throughput = 1 << 20;
	}
	else if ((strstr(device_name[dev_id], "960")))
	{
		default_throughput = 1 << 20;
	}
	else if ((strstr(device_name[dev_id], "750")))
	{
		default_throughput = 1 << 20;
	}
	else if ((strstr(device_name[dev_id], "1060")) || (strstr(device_name[dev_id], "P106")))
	{
		default_throughput = (1 << 21);
	}
	else if ((strstr(device_name[dev_id], "970") || (strstr(device_name[dev_id], "980"))))
	{
		default_throughput = (1 << 21);
	}
	else if ((strstr(device_name[dev_id], "166")) || (strstr(device_name[dev_id], "20")))
	{
		default_throughput = (1 << 21);
	}
	else if (strstr(device_name[dev_id], "1070") || (strstr(device_name[dev_id], "P104")))
	{
		default_throughput = (1 << 21);
	}
	else if ((strstr(device_name[dev_id], "1080 Ti")) || (strstr(device_name[dev_id], "1080")) || (strstr(device_name[dev_id], "P102")))
	{
		default_throughput = (1 << 21);
	}
	uint32_t throughput = cuda_default_throughput(thr_id, default_throughput);
	if (init[thr_id]) throughput = min(throughput, max_nonce - first_nonce);

	if (!init[thr_id])
	{
		cudaSetDevice(device_map[thr_id]);
		if (opt_cudaschedule == -1 && gpu_threads == 1) {
			cudaDeviceReset();
			// reduce cpu usage
			cudaSetDeviceFlags(cudaDeviceScheduleBlockingSync);
		}
		gpulog(LOG_INFO, thr_id, "Intensity set to %g, %u cuda threads", throughput2intensity(throughput), throughput);

		quark_blake512_cpu_init(thr_id, throughput);
		quark_bmw512_cpu_init(thr_id, throughput);
		quark_groestl512_cpu_init(thr_id, throughput);
		quark_skein512_cpu_init(thr_id, throughput);
		quark_jh512_cpu_init(thr_id, throughput);
		quark_keccak512_cpu_init(thr_id, throughput);
		qubit_luffa512_cpu_init(thr_id, throughput);
		x11_luffa512_cpu_init(thr_id, throughput); // 64
		x11_shavite512_cpu_init(thr_id, throughput);
		x11_simd512_cpu_init(thr_id, throughput); // 64
		x11_echo512_cpu_init(thr_id, throughput);
		x16_echo512_cuda_init(thr_id, throughput);
		x13_hamsi512_cpu_init(thr_id, throughput);
		x13_fugue512_cpu_init(thr_id, throughput);
		x16_fugue512_cpu_init(thr_id, throughput);
		x14_shabal512_cpu_init(thr_id, throughput);
		x15_whirlpool_cpu_init(thr_id, throughput, 0);
		x16_whirlpool512_init(thr_id, throughput);
		x17_sha512_cpu_init(thr_id, throughput);
		x17_haval256_cpu_init(thr_id, throughput);

		CUDA_CALL_OR_RET_X(cudaMalloc(&d_hash[thr_id], (size_t) 64 * throughput), 0);

		cuda_check_cpu_init(thr_id, throughput);

		init[thr_id] = true;
	}

	if (opt_benchmark) {
		//((uint32_t*)ptarget)[7] = 0x003f;
		//((uint8_t*)pdata)[8] = 0x90; // hashOrder[0] = '9'; for simd 80 + blake512 64
		//((uint8_t*)pdata)[8] = 0xA0; // hashOrder[0] = 'A'; for echo 80 + blake512 64
		//((uint8_t*)pdata)[8] = 0xB0; // hashOrder[0] = 'B'; for hamsi 80 + blake512 64
		//((uint8_t*)pdata)[8] = 0xC0; // hashOrder[0] = 'C'; for fugue 80 + blake512 64
		//((uint8_t*)pdata)[8] = 0xE0; // hashOrder[0] = 'E'; for whirlpool 80 + blake512 64
	}
	uint32_t _ALIGN(64) endiandata[20];

	for (int k=0; k < 20; k++)
		endiandata[k] = pdata[k];

	//char endiandata_str[161];
	//memset(endiandata_str, 0x0, sizeof(endiandata_str));
	//for (int k = 0; k < 80; k++)
	//	sprintf(endiandata_str + 2 * k, "%02x", ((uint8_t*)endiandata)[k]);
	//printf("%s\n", endiandata_str);

	uint32_t ntime = swab32(pdata[0]);
	if (s_ntime != ntime) {
		getAlgoString(&endiandata[1], hashOrder);
		//applog(LOG_INFO, "hashOrder %s ", hashOrder);
		s_ntime = ntime;
		s_implemented = true;
		if (opt_debug && !thr_id) applog(LOG_DEBUG, "hash order %s (%08x)", hashOrder, ntime);
	}

	if (!s_implemented) {
		sleep(1);
		return -1;
	}

	cuda_check_cpu_setTarget(ptarget);

	
	quark_blake512_cpu_setBlock_80(thr_id, endiandata);
	int warn = 0;

	do {
		int order = 0;

		// Hash with CUDA

		

		quark_blake512_cpu_hash_80(thr_id, throughput, pdata[19], d_hash[thr_id]);
	

		quark_bmw512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		quark_groestl512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		quark_skein512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		quark_jh512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		quark_keccak512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);
		

		x11_luffa512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		x11_cubehash512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		x11_shavite512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);
				
		x11_simd512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		x11_echo512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		x13_hamsi512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);


		x13_fugue512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		x14_shabal512_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		x15_whirlpool_cpu_hash_64(thr_id, throughput, pdata[19], NULL, d_hash[thr_id], order++);

		x17_sha512_cpu_hash_64(thr_id, throughput, pdata[19], d_hash[thr_id]); order++;

		x17_haval256_cpu_hash_64(thr_id, throughput, pdata[19], d_hash[thr_id], 256); order++;


		*hashes_done = pdata[19] - first_nonce + throughput;

		work->nonces[0] = cuda_check_hash(thr_id, throughput, pdata[19], d_hash[thr_id]);
//#ifdef _DEBUG
//		uint32_t _ALIGN(64) dhash[8];
//		be32enc(&endiandata[19], pdata[19]);
//		x17_hash(dhash, endiandata);
//		applog_hash(dhash);
//		return -1;
//#endif
		if (work->nonces[0] != UINT32_MAX)
		{
			if (opt_benchmark) gpulog(LOG_BLUE, dev_id, "found");

			const uint32_t Htarg = ptarget[7];
			uint32_t _ALIGN(64) vhash[8];
			be32enc(&endiandata[19], work->nonces[0]);
			x17_hash(vhash, endiandata);

			if (vhash[7] <= Htarg && fulltest(vhash, ptarget)) {
				//gpulog(LOG_INFO, thr_id, "result info vhash 7 %08x,Htarg :%08x,all hash %08x%08x%08x%08x%08x%08x%08x%08x ,target: %08x%08x%08x%08x%08x%08x%08x%08x", vhash[7], Htarg, vhash[7], vhash[6], vhash[5], vhash[4], vhash[3], vhash[2], vhash[1], vhash[0], ptarget[7], ptarget[6], ptarget[5], ptarget[4], ptarget[3], ptarget[2], ptarget[1], ptarget[0]);
				//if (!opt_quiet)	gpulog(LOG_INFO, thr_id, "result for %08x validate on CPU! %s %s",
				//	work->nonces[0], algo_strings[algo80], hashOrder);

				work->valid_nonces = 1;
				work->nonces[1] = cuda_check_hash_suppl(thr_id, throughput, pdata[19], d_hash[thr_id], 1);
				work_set_target_ratio(work, vhash);
				if (work->nonces[1] != 0) {
					be32enc(&endiandata[19], work->nonces[1]);
					x17_hash(vhash, endiandata);
					bn_set_target_ratio(work, vhash, 1);
					work->valid_nonces++;
					pdata[19] = max(work->nonces[0], work->nonces[1]) + 1;
				} else {
					pdata[19] = work->nonces[0] + 1; // cursor
				}
#if 0
				gpulog(LOG_INFO, thr_id, "hash found with %s 80!", algo_strings[algo80]);

				algo80_tests[algo80] += work->valid_nonces;
				char oks64[128] = { 0 };
				char oks80[128] = { 0 };
				char fails[128] = { 0 };
				for (int a = 0; a < HASH_FUNC_COUNT; a++) {
					const char elem = hashOrder[a];
					const uint8_t algo64 = elem >= 'A' ? elem - 'A' + 10 : elem - '0';
					if (a > 0) algo64_tests[algo64] += work->valid_nonces;
					sprintf(&oks64[strlen(oks64)], "|%X:%2d", a, algo64_tests[a] < 100 ? algo64_tests[a] : 99);
					sprintf(&oks80[strlen(oks80)], "|%X:%2d", a, algo80_tests[a] < 100 ? algo80_tests[a] : 99);
					sprintf(&fails[strlen(fails)], "|%X:%2d", a, algo80_fails[a] < 100 ? algo80_fails[a] : 99);
				}
				applog(LOG_INFO, "K64: %s", oks64);
				applog(LOG_INFO, "K80: %s", oks80);
				applog(LOG_ERR,  "F80: %s", fails);
#endif
				return work->valid_nonces;
			}
			else if (vhash[7] > Htarg) {
				// x11+ coins could do some random error, but not on retry
				gpu_increment_reject(thr_id);
				if (!warn) {
					warn++;
					pdata[19] = work->nonces[0] + 1;
					continue;
				} else {
					//if (!opt_quiet)	{
					//	gpulog(LOG_WARNING, thr_id, "result for %08x does not validate on CPU! %s %s",
					//		work->nonces[0], algo_strings[algo80], hashOrder);
					//}
					warn = 0;
					return 0;
				}
			}
		}

		if ((uint64_t)throughput + pdata[19] >= max_nonce) {
			pdata[19] = max_nonce;
			break;
		}

		pdata[19] += throughput;

	} while (pdata[19] < max_nonce && !work_restart[thr_id].restart);

	*hashes_done = pdata[19] - first_nonce;
	return 0;
}

// cleanup
extern "C" void free_x17(int thr_id)
{
	if (!init[thr_id])
		return;

	cudaThreadSynchronize();

	cudaFree(d_hash[thr_id]);

	quark_blake512_cpu_free(thr_id);
	quark_groestl512_cpu_free(thr_id);
	x11_simd512_cpu_free(thr_id);
	x13_fugue512_cpu_free(thr_id);
	x16_fugue512_cpu_free(thr_id); // to merge with x13_fugue512 ?
	x15_whirlpool_cpu_free(thr_id);

	cuda_check_cpu_free(thr_id);

	cudaDeviceSynchronize();
	init[thr_id] = false;
}
