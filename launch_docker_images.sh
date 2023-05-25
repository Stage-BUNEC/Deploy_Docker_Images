#!/bin/bash

################################################################################
#                                                                              #
# [ Created At ]   : 16-05-2023                                                #
# [ LastUpdate ]   : 25-05-2023                                                #
# [ Description ]  : Script de config des Conteneurs Docker                    #
# [ Author(s) ]    : NANFACK STEVE ULRICH                                      #
# [ email(s) ]     : nanfacksteve7@gmail.com                                   #
# [ contributors ] : Mr EVEGA Serge (BUNEC)                                    #
#                                                                              #
################################################################################

images_list="$1"
docker_compose_dir="$2"
certificates_dir="$3"
web_app="$4"
env_file="$5"

target_web_app_dir="/home/bunec/"
deploy_web_app_dir="/var/www/html"
certificates_web_app_dir="/var/www/certificats"
DIGIT_CONTAINER="etat.civil"

################################################################################
#                         FUNCTION DECLARATION                                 #
################################################################################

red='\e[1;31m' && grn='\e[1;32m' && vlt='\e[1;35m' && ylw='\e[1;93m' blu='\e[1;94m' && nc='\e[0m' # Color's Message

check_if_image_is_load() {

    docker_image="$1"
    if [ -z "$docker_image" ]; then
        echo -e "$red\nError: Missing image name ! $nc\n"
        exit 1
    fi

    # check if $docker_image is load
    [[ -z "$(docker images --format {{.Repository}} | grep -w "$docker_image")" ]] && is_present=false || is_present=true

    # return the result
    echo $is_present

}

deploy_docker_stack() {

    stack_dir="$1"
    if [ -z "$stack_dir" ]; then
        echo -e "$red\nError: Missing docker compose folder ! $nc\n"
        exit 1
    fi

    if [ ! -d "$stack_dir" ]; then
        echo -e "$red\nError: $stack_dir folder doesn't exist ! $nc\n"
        exit 1
    fi

    # Deployment of each Docker-compose.yml file
    for compose_file in $(find "${stack_dir}" -name "docker-compose*.yml"); do
        if [ -f $compose_file ]; then
            docker-compose -f "$compose_file" up -d
            if [ $? -eq 0 ]; then
                echo -e "\n$grn[ ✔ ]$nc - $grn Success deployment of $nc($compose_file)\n"
            else
                echo -e "\n$red[ ✗ ]$nc - $red Error on deployment of $nc($compose_file)\n"
            fi
        fi
    done
}

print_help() {
    echo -e "\n(Bad script usage) \nUsing: ./launch_docker_images.sh \e[4marg1$nc \e[4marg2$nc \e[4marg3$nc \e[4marg4$nc \e[4marg5$nc\n"
    echo -e "Where:\t arg1 := images_list_file"
    echo -e "\t arg2 := docker_compose_folder"
    echo -e "\t arg3 := certificates_folder"
    echo -e "\t arg4 := compressed_web_app_file"
    echo -e "\t arg5 := environment_file\n"
}

################################################################################
#                                 MAIN PROGRAM                                 #
################################################################################

# +----------------------+
# | Check ALL Parameters |
# +----------------------+

# Check Arg number
[[ "$#" -ne 5 ]] && print_help && exit 1

# Check if File or Folder exist
[[ ! -f "$images_list" ]] && echo -e "\n$red[Error] : $nc($images_list)$red File doesn't exist !!! $nc\n" && exit 1
[[ ! -d "$docker_compose_dir" ]] && echo -e "\n$red[Error] : $nc($docker_compose_dir)$red Folder doesn't exist !!! $nc\n" && exit 1
[[ ! -d "$certificates_dir" ]] && echo -e "\n$red[Error] : $nc($certificates_dir)$red Folder doesn't exist !!! $nc\n" && exit 1
[[ ! -f "$web_app" ]] && echo -e "\n$red[Error] : $nc($web_app)$red Compressed File doesn't exist !!! $nc\n" && exit 1
[[ ! -f "$env_file" ]] && echo -e "\n$red[Error] : $nc($env_file)$red File doesn't exist !!! $nc\n" && exit 1

# Add '/' at end of folder path
[[ "$2" = */ ]] && docker_compose_dir="$2" || docker_compose_dir="$2/"
[[ "$3" = */ ]] && certificates_dir="$3" || certificates_dir="$3/"

# Get docker images list from file
read -r -a docker_images <<<"$(cat "$images_list")"

# +-------------------------------------+
# | STEP 1 : CHECK IF IMAGES ARE LOADED |
# +-------------------------------------+

echo -e "\nStart Checking Images Loaded Locally"
echo -e "--------------------------------------\n"

for image in ${docker_images[@]}; do

    image_is_load=$(check_if_image_is_load "$image")

    if $image_is_load; then
        echo -e "\n$grn[ ✔ ]$nc - $ylw$image$grn is load localy ! \n$nc"
    else
        echo -e "\n$red[ ✗ ]$nc - $ylw$image$red is NOT load !$nc"
        echo -e "[warning] : pulling missing image ! it's may take time ...\n"
    fi
done

# +--------------------------------------------+
# | STEP 2 : DEPLOY ALL STACK (DOCKER-COMPOSE) |
# +--------------------------------------------+

echo -e "\nStarting Deployment of Stack"
echo -e "-------------------------------\n"
deploy_docker_stack "$docker_compose_dir"

# +-----------------------------------------------+
# | STEP 3 : CHECK IF "DIGIT CONTAINER IS RUNNING |
# +-----------------------------------------------+

digit_is_running=$(docker inspect "$DIGIT_CONTAINER" --format {{.State.Running}})

# +----------------------------------+
# | STEP 4 : CONFIGURE DIGIT WEB APP |
# +----------------------------------+

if $digit_is_running; then

    echo -e "\n🆗 -$blu Container $DIGIT_CONTAINER is running ! $nc\n"

    digit_is_ok=true
    errors_task=("Copying Digt Web App" "Extracting digit Web App" "Copying Certificates" "Changing Mode" "Deleting Index file")

    # COPY OF WEB APP INTO DIGIT
    docker cp "$web_app" "$DIGIT_CONTAINER":"$target_web_app_dir"
    [[ $? -eq 0 ]] && echo -e "\n$grn[ ✔ ]$nc -$grn Copy digit web app in container successfully ! $nc\n" || (digit_is_ok=false && state=0)

    # EXTRACT WEB APP
    docker exec "$DIGIT_CONTAINER" unzip "$target_web_app_dir/$web_app" -d "$deploy_web_app_dir"
    [[ $? -eq 0 ]] && echo -e "\n$grn[ ✔ ]$nc -$grn Extract digit web app in container successfully ! $nc\n" || (digit_is_ok=false && state=1)

    # COPY OF CERTIFICATES
    docker cp "$certificates_dir" "$DIGIT_CONTAINER":"$certifates_web_app_dir"
    [[ $? -eq 0 ]] && echo -e "\n$grn[ ✔ ]$nc -$grn Copy of certificates in container successfully ! $nc\n" || (digit_is_ok=false && state=2)

    # CHANGE ACCESS DIR
    docker exec "$DIGIT_CONTAINER" chmod 777 "$certificates_web_app_dir"
    [[ $? -eq 0 ]] && echo -e "\n$grn[ ✔ ]$nc -$grn Changing access of $certificates_dir successfully ! $nc\n" || (digit_is_ok=false && state=3)

    # REMOVE HTML INDEX FILE FROM WEB_APP
    docker exec "$DIGIT_CONTAINER" rm "$deploy_web_app_dir"/index.html
    [[ $? -eq 0 ]] && echo -e "\n$grn[ ✔ ]$nc -$grn Removing index.html from '$deploy_web_app_dir' successfully ! $nc\n" || (digit_is_ok=false && state=4)

    # CHECK IF DIGIT IS COMPLETE CONFIGURATE
    if $digit_is_ok; then

        #clear
        echo -e "\n$grn                           @@@@@@@@@@@@@@@@@@@@@@@"
        echo -e "$grn                                                 #"
        echo -e "$grn#            DEPLOYMENT IS SUCCESSFUL            #"
        echo -e "$grn#"
        echo -e "$grn#@@@@@@@@@@@@@@@@@@@ $nc\n"
    else
        echo "\n\n$ylw[i] : Container $nc($DIGIT_CONTAINER)$ylw is running but not complete configurate..."
        echo "$red ✗ $nc -$red Somthing wrong on $ylw${errors_task[$state]} !$nc\n\n"
    fi

else
    echo -e "\n\n$red""[ Error ] :$nc $DIGIT_CONTAINER ""$red""is not running !$nc\n"
fi

# +--------------------------------------------------------------+
# | STEP 5 : DELETE DOCKER STACK/COMPOSE And CERTIFICATES FOLDER |
# +--------------------------------------------------------------+

#if [ -d "$docker_compose_dir" ]; then rm -r "$docker_compose_dir"; fi
#if [ -d "$certificates_dir" ]; then rm -r "$certificates_dir"; fi
