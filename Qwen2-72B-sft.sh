# You can observe that the number of steps for different stage is quite different. They are not magic number. They are set to those numbers simply because I esitimate the time it takes to finish the training, and 
# choose the number such that it fits my daily schedule>_<. This is for you to exactly reproduce my results. You many change the steps to other numbers if you want to.
MODEL_DIR=${MODEL_DIR:-"/mnt/zj-gpfs/home/lsy/models/Meta-Llama-3-8B"}
MODEL_TYPE=${MODEL_TYPE:-Qwen2-72B}
NGPUS=${NGPUS:-8}
WORLD_SIZE=${WORLD_SIZE:-1}
NUM_PROCESSES=$((${NGPUS}*${WORLD_SIZE}))
SEQ_LEN=${SEQ_LEN:-32768}
BATCH_SIZE=${BATCH_SIZE:-1}
ACC=${ACC:-6}
SAVE_PATH=${SAVE_PATH:-"./output/70B_32K_bs_1M_rope_1M_step_1000_lr_2e-5"}
export PYTORCH_CUDA_ALLOC_CONF='max_split_size_mb:1024' 
export NCCL_P2P_DISABLE=1
export NCCL_IB_GID_INDEX=3
export WANDB_DISABLED=true
export NCCL_DEBUG=WARN
export CUDA_LAUNCH_BLOCKING=1
echo ${RANK}/$[WORLD_SIZE]
if [ ${MASTER_ADDR} == 'localhost' ]; then
    export MASTER_ADDR=`hostname -i`
fi
if [ ${MODEL_TYPE} == 'Qwen2-72B' ]; then
    llamafy_config="/nas/lsy/models/llamafyqwenconfigs/Qwen2-72Bconfig.json"
    original_config="/mnt/zj-gpfs/home/lsy/models/qwenconfigs/Qwen2-72Bconfig.json"
elif [ ${MODEL_TYPE} == 'Qwen2.5-7B' ]; then
    llamafy_config="/nas/lsy/models/llamafyqwenconfigs/Qwen2.5-7Bconfig.json"
    original_config="/mnt/zj-gpfs/home/lsy/models/qwenconfigs/Qwen2.5-7Bconfig.json"
elif [ ${MODEL_TYPE} == 'Qwen2.5-72B' ]; then
    llamafy_config="/nas/lsy/models/llamafyqwenconfigs/Qwen2.5-72Bconfig.json"
    original_config="/mnt/zj-gpfs/home/lsy/models/qwenconfigs/Qwen2.5-72Bconfig.json"
fi

# cp "$llamafy_config" "${MODEL_DIR}/config.json"


echo ${MASTER_ADDR}:${MASTER_PORT}
# those configs are set according to ali sft script
accelerate launch \
--config_file examples/accelerate/ds_multi_nodes.yaml \
--use_deepspeed \
--num_machines ${WORLD_SIZE} \
--num_processes ${NUM_PROCESSES} \
--main_process_ip ${MASTER_ADDR} \
--main_process_port ${MASTER_PORT} \
--machine_rank ${RANK} \
--rdzv_conf "rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT,rdzv_backend=c10d" \
src/train.py \
--model_name_or_path ${MODEL_DIR} \
--stage sft \
--do_train \
--finetuning_type full \
--flash_attn ${FLASH_ATTN:-auto} \
--parallel_mode ${PARALLEL_MODE:-dist_flash_attn} \
--deepspeed examples/deepspeed/ds_z3_offload_config.json \
--sp_size ${SP_SIZE:-8} \
--dataset ${DATASET:-long_sft_32k} \
--template ${TEMPLATE:-qwen} \
--cutoff_len ${SEQ_LEN} \
--max_samples 20000000 \
--overwrite_cache \
--preprocessing_num_workers 16 \
--output_dir ${SAVE_PATH} \
--logging_steps 1 \
--save_strategy epoch \
--plot_loss \
--average_tokens_across_devices \
--overwrite_output_dir \
--per_device_train_batch_size ${BATCH_SIZE} \
--gradient_accumulation_steps ${ACC} \
--learning_rate ${LR:-2e-5} \
--lr_scheduler_kwargs {\"lr_end\":1e-7} \
--num_train_epochs 1.0 \
--lr_scheduler_type polynomial \
--warmup_ratio 0.0 \
--weight_decay 0.1 \
--bf16 \
--ddp_timeout 180000000 \
--val_size 0.0 \
--eval_strategy no \
--dataloader_drop_last
#--disable_gradient_checkpointing \

cp "$original_config" "${MODEL_DIR}/config.json"
cp "$original_config" "${SAVE_PATH}/config.json"

# In the saved files, there are model-00001-of-00003.safetensors to model-00001-of-00003.safetensors. Somehow model.safetensors is unnecessary and should be removed.
# rm output/7B_32K_bs_1M_rope_1M_step_1000_lr_2e-5/model.safetensors

# accelerate launch \
# --config_file  accelerate_configs/single_node.yaml \
# train.py \
# --batch-size 1 \
# --gradient-accumulate-every 2 \
# --output-dir ./output/7B_64K_bs_1M_rope_5M_step_1000_lr_2e-5 \
# --seed 2022 \
# --wandb EasyContext \
# --max-train-steps 1000  \
# --learning-rate 2e-5  \
# --dataset yaofu/slimpajama-per-source-length-upsample \
# --model output/7B_32K_bs_1M_rope_1M_step_1000_lr_2e-5  \
# --seq-length 65536 \
# --rope-theta 5000000 \
# --parallel_mode data_parallel

# rm output/7B_64K_bs_1M_rope_5M_step_1000_lr_2e-5/model.safetensors

# accelerate launch \
# --config_file  accelerate_configs/single_node.yaml \
# train.py \
# --batch-size 1 \
# --gradient-accumulate-every 4  \
# --output-dir  ./output/7B_0.256M_bs_1M_rope_10M_step_500_lr_2e-5 \
# --seed 2023 \
# --wandb EasyContext \
# --max-train-steps 500  \
# --learning-rate 2e-5  \
# --dataset PY007/slimpajama_llama_tokenized_upsample_4096_chunk_256K \
# --model output/7B_64K_bs_1M_rope_5M_step_1000_lr_2e-5  \
# --seq-length 256000 \
# --rope-theta 10000000 \
# --parallel_mode zigzag_ring_attn

# rm output/7B_0.256M_bs_1M_rope_10M_step_500_lr_2e-5/model.safetensors

# accelerate launch \
# --config_file accelerate_configs/single_node.yaml \
# train.py \
# --batch-size 1 \
# --gradient-accumulate-every 4  \
# --output-dir  ./output/7B_0.256M_bs_1M_rope_25M_step_500_lr_2e-5 \
# --seed 2024 \
# --wandb EasyContext \
# --max-train-steps 500  \
# --learning-rate 2e-5  \
# --dataset PY007/slimpajama_llama_tokenized_upsample_4096_chunk_256K \
# --model output/7B_0.256M_bs_1M_rope_10M_step_500_lr_2e-5  \
# --seq-length 256000 \
# --rope-theta 25000000 \
# --parallel_mode zigzag_ring_attn

# rm output/7B_0.256M_bs_1M_rope_25M_step_500_lr_2e-5/model.safetensors

# accelerate launch \
# --config_file accelerate_configs/single_node.yaml \
# train.py \
# --batch-size 1 \
# --gradient-accumulate-every 4  \
# --output-dir  ./output/7B_0.256M_bs_1M_rope_50M_step_150_lr_2e-5 \
# --seed 2025 \
# --wandb EasyContext \
# --max-train-steps 150  \
# --learning-rate 2e-5  \
# --dataset PY007/slimpajama_llama_tokenized_upsample_4096_chunk_256K \
# --model output/7B_0.256M_bs_1M_rope_25M_step_500_lr_2e-5  \
# --seq-length 256000 \
# --rope-theta 50000000 \
# --parallel_mode zigzag_ring_attn

# rm output/7B_0.256M_bs_1M_rope_50M_step_150_lr_2e-5/model.safetensors

# accelerate launch \
# --config_file accelerate_configs/single_node.yaml \
# train.py \
# --batch-size 1 \
# --gradient-accumulate-every 2  \
# --output-dir  ./output/7B_0.5M_bs_1M_rope_100M_step_300_lr_2e-5 \
# --seed 2026 \
# --wandb EasyContext \
# --max-train-steps 300  \
# --learning-rate 2e-5  \
# --dataset PY007/slimpajama_llama_tokenized_upsample_4096_chunk_1M \
# --model output/7B_0.256M_bs_1M_rope_50M_step_150_lr_2e-5  \
# --seq-length 512000 \
# --rope-theta 100000000 \
# --parallel_mode zigzag_ring_attn


# rm output/7B_0.5M_bs_1M_rope_100M_step_300_lr_2e-5/model.safetensors

# accelerate launch \
# --config_file accelerate_configs/single_node.yaml \
# train.py \
# --batch-size 1 \
# --gradient-accumulate-every 2  \
# --output-dir  ./output/7B_0.5M_bs_1M_rope_250M_step_90_lr_2e-5 \
# --seed 2027 \
# --wandb EasyContext \
# --max-train-steps 90  \
# --learning-rate 1e-5  \
# --dataset PY007/slimpajama_llama_tokenized_upsample_4096_chunk_1M \
# --model output/7B_0.5M_bs_1M_rope_100M_step_300_lr_2e-5  \
# --seq-length 512000 \
# --rope-theta 250000000 \
# --parallel_mode zigzag_ring_attn

# rm output/7B_0.5M_bs_1M_rope_250M_step_90_lr_2e-5/model.safetensors


### Finally we directly set the rope_theta in output/7B_0.5M_bs_1M_rope_250M_step_90_lr_2e-5/config.json to 1,000,000,000
