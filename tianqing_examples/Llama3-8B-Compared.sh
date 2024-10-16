MODEL_DIR=${MODEL_DIR:-"/mnt/zj-gpfs/home/qianhao/models/Meta-Llama-3-8B"}
NGPUS=${NGPUS:-8}
WORLD_SIZE=${WORLD_SIZE:-1}
NUM_PROCESSES=$((${NGPUS} * $((WORLD_SIZE))))
SEQ_LEN=${SEQ_LEN:-32768}
SP_SIZE=8
BATCH_SIZE=${BATCH_SIZE:-1}
BATCH_SIZE=1
CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
ALGO=llama3_flash_attn
# COMPARED_ALGO=data_parallel
COMPARED_ALGO=dist_flash_attn
COMPARED_ALGO_2=lss_transformer
# COMPARED_ALGO=zigzag_ring_attn
NSYSPROFILE=true
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
export PYTORCH_CUDA_ALLOC_CONF='max_split_size_mb:1024'
export WANDB_DISABLED=true
export NCCL_DEBUG=WARN
RANK=0
echo ${RANK}/$((WORLD_SIZE))
MASTER_ADDR=localhost
MASTER_PORT=29500
if [ ${MASTER_ADDR} = 'localhost' ]; then
    export MASTER_ADDR=$(hostname -i)
fi
echo "MASTER_IP:MASTER_PORT"
echo ${MASTER_ADDR}:${MASTER_PORT}
echo "NUM_PROCESSER is ${NUM_PROCESSES}"
echo "NGPUS is ${NGPUS}"
echo "WORLD_SIZE is ${WORLD_SIZE}"
echo "SEQ_LEN is ${SEQ_LEN}"
echo "SP_SIZE is ${SP_SIZE}"
echo "BATCH_SIZE is ${BATCH_SIZE}"

run_accelerate(){
    local algo=$1 
    local output_dir=$2
    local nsys_profile=$3
    if $nsys_profile
    then
        accelerate launch --config_file examples/accelerate/ds_multi_nodes.yaml \
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
        --parallel_mode ${algo} \
        --sp_size ${SP_SIZE} \
        --deepspeed examples/deepspeed/ds_z3_offload_config.json \
        --dataset long_sft_32k \
        --template llama3 \
        --cutoff_len ${SEQ_LEN} \
        --max_steps 10 \
        --overwrite_cache \
        --preprocessing_num_workers 16 \
        --output_dir ./output/7B_4K_bs_2_lr_2e-5_${algo}_${TIMESTAMP} \
        --logging_steps 1 \
        # --save_steps 500 \
        --plot_loss \
        --overwrite_output_dir \
        --per_device_train_batch_size ${BATCH_SIZE} \
        --gradient_accumulation_steps 1 \
        --learning_rate 2e-5 \
        --num_train_epochs 1.0 \
        --lr_scheduler_type cosine \
        --warmup_ratio 0.1 \
        --bf16 \
        --ddp_timeout 180000000 \
        --val_size 0.1 \
        --eval_strategy steps \ 
        --eval_steps 1000
    else
        nsys profile -t cuda,osrt,nvtx,cublas,cudnn -w true \
        --cudabacktrace=all --force-overwrite true -o $output_dir
        accelerate launch --config_file examples/accelerate/ds_multi_nodes.yaml \
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
        --parallel_mode ${algo} \
        --sp_size ${SP_SIZE} \
        --deepspeed examples/deepspeed/ds_z3_offload_config.json \
        --dataset long_sft_32k \
        --template llama3 \
        --cutoff_len ${SEQ_LEN} \
        --max_steps 10 \
        --overwrite_cache \
        --preprocessing_num_workers 16 \
        --output_dir ./output/7B_4K_bs_2_lr_2e-5_${algo}_${TIMESTAMP} \
        --logging_steps 1 \
        # --save_steps 500 \
        --plot_loss \
        --overwrite_output_dir \
        --per_device_train_batch_size ${BATCH_SIZE} \
        --gradient_accumulation_steps 1 \
        --learning_rate 2e-5 \
        --num_train_epochs 1.0 \
        --lr_scheduler_type cosine \
        --warmup_ratio 0.1 \
        --bf16 \
        --ddp_timeout 180000000 \
        --val_size 0.1 \
        --eval_strategy steps \
        --eval_steps 1000     
    fi 
}


if [ ! -z ${ALGO+x} ]; then
    run_accelerate ${ALGO} "./output/7B_4K_bs_2_lr_2e-5_${algo}_${TIMESTAMP}/nsys_${algo}" ${NSYSPROFILE}
fi
