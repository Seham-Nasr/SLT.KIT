#!/bin/bash

input=$1
name=$2

language=$3

size=512
if [ $# -ne 3 ]; then
    size=$4
fi
innersize=$((size*4))

if [ -z $LAYER ]; then
    LAYER=8
fi

if [ -z $ENC_LAYER ]; then
    ENC_LAYER=$LAYER
fi

if [ -z $TRANSFORMER ]; then
    TRANSFORMER=transformer
fi


if [ -z "$BASEDIR" ]; then
    BASEDIR=/
fi

if [ -z "$NMTDIR" ]; then
    NMTDIR=/opt/NMTGMinor/
fi

if [ -z "$GPU" ]; then
    GPU=0
fi

if [ $GPU -eq -1 ]; then
    gpu_string_train=""
    gpu_string_avg=""
else
    gpu_string_train="-gpus "$GPU
    gpu_string_avg="-gpu "$GPU
fi

if [ ! -z "$FP16" ]; then
    gpu_string_train=$gpu_string_train" -fp16"
fi

mkdir -p $BASEDIR/tmp/${name}/
mkdir -p $BASEDIR/model/${name}/
mkdir -p $BASEDIR/model/${name}/checkpoints/




# for l in scp s t
# do
#     for set in train valid
#     do
#        echo -n "" > $BASEDIR/tmp/${name}/$set.$l
#        for f in $BASEDIR/data/${input}/${set}/*\.${l}
#        do
	   
#  	   cat $f >> $BASEDIR/tmp/${name}/$set.$l
#        done
#     done
# done

 # python3 $NMTDIR/preprocess.py \
 #         -train_src $BASEDIR/tmp/${name}/train.s \
 #         -train_tgt $BASEDIR/tmp/${name}/train.t \
 #        -valid_src $BASEDIR/tmp/${name}/valid.s \
 #        -valid_tgt $BASEDIR/tmp/${name}/valid.t \
 #        -src_seq_length 512 \
 #        -tgt_seq_length 512 \
 #        -join_vocab \
 #        -save_data $BASEDIR/model/${name}/train.text

 # python3 $NMTDIR/preprocess.py \
 #         -train_src $BASEDIR/tmp/${name}/train.scp \
 #         -train_tgt $BASEDIR/tmp/${name}/train.$language \
 #        -valid_src $BASEDIR/tmp/${name}/valid.scp \
 #        -valid_tgt $BASEDIR/tmp/${name}/valid.$language \
 #        -src_seq_length 1024 \
 #        -tgt_seq_length 512 \
 #        -tgt_vocab $BASEDIR/model/${name}/train.text.tgt.dict\
 #        -concat 4 -asr -src_type audio\
 #        -asr_format scp\
 #        -save_data $BASEDIR/model/${name}/train.audio

python3 -u $NMTDIR/train.py  -data $BASEDIR/model/${name}/train.audio -data_format raw \
       -additional_data $BASEDIR/model/${name}/train.text -additional_data_format raw \
       -data_ratio "1;1" \
       -save_model $BASEDIR/model/${name}/checkpoints/model \
       -model $TRANSFORMER \
       -batch_size_words 2048 \
       -batch_size_update 24568 \
       -batch_size_sents 9999 \
       -batch_size_multiplier 8 \
       -encoder_type mix \
       -checkpointing 0 \
       -input_size 172 \
       -layers $LAYER \
       -encoder_layer $ENC_LAYER \
       -death_rate 0.5 \
       -model_size $size \
       -inner_size $innersize \
       -n_heads 8 \
       -dropout 0.2 \
       -attn_dropout 0.2 \
       -word_dropout 0.1 \
       -emb_dropout 0.2 \
       -label_smoothing 0.1 \
       -epochs 64 \
       -learning_rate 2 \
       -optim 'adam' \
       -update_method 'noam' \
       -normalize_gradient \
       -warmup_steps 8000 \
       -max_generator_batches 8192 \
       -tie_weights \
       -seed 8877 \
       -log_interval 1000 \
       $gpu_string_train #&> $BASEDIR/model/${name}/train.log

exit;

checkpoints=""

for f in `ls $BASEDIR/model/${name}/checkpoints/model_ppl_*`
do
    checkpoints=$checkpoints"${f}|"
done
checkpoints=`echo $checkpoints | sed -e "s/|$//g"`


python3 -u $NMTDIR/average_checkpoints.py $gpu_string_avg \
                                    -models $checkpoints \
                                    -output $BASEDIR/model/${name}/model.pt

rm -r $BASEDIR/tmp/${name}/
