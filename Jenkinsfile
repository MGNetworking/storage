pipeline {
    agent any

    environment {

        Nexus_CREDS = credentials('nexus-credentials')
        Nas_CREDS = credentials('NAS')
        NAS_SERVER = 'nas.backhole.ovh'
        TEST_TOKEN = credentials('test-jwt-token')

        MAVEN_OPTS = '-Xmx1024m -XX:+UseG1GC'
        DOCKER_REGISTRY = 'sonatype-nexus.backhole.ovh'
        APP_NAME = 'file-storage-api'
        APP_PORT = 8666

        // Tags intelligents pour traçabilité
        GIT_TAG = sh(script: "git describe --tags --always", returnStdout: true).trim()
        IMAGE_TAG = "${GIT_TAG}-${BUILD_NUMBER}"
    }

    stages {
        // ========================================
        // BRANCHE FEATURE : Tests + Build + Push
        // ========================================
        stage('Tests unitaires') {
            when { branch 'feature' }
            steps {
                echo "🧪 Exécution des tests unitaires..."
                sh '''
                    ./mvnw clean test
                '''

                // Publication des résultats de tests
                publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
                publishCoverage adapters: [jacocoAdapter('target/site/jacoco/jacoco.xml')]
            }
        }

        stage('Compilation projet') {
            when { branch 'feature' }
            steps {
                echo "🔨 Compilation du projet..."
                sh '''
                    ./mvnw clean package -DskipTests
                '''

                // Archive l'artifact pour utilisation Docker
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Push vers Nexus') {
            when {
                allOf {
                    branch 'feature'
                    expression { currentBuild.currentResult == 'SUCCESS' }
                }
            }
            steps {
                echo "📦 Build et push de l'image Docker vers Nexus..."
                // Utilisation du Docker Pipeline Plugin
                docker.withRegistry("https://${DOCKER_REGISTRY}", 'nexus-credentials') {
                    def image = docker.build("${APP_NAME}:${IMAGE_TAG}")

                    // Push avec tag versioned
                    image.push()

                    // Push avec tag latest
                    image.push('latest')

                    echo "✅ Image pushée: ${DOCKER_REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
                    echo "✅ Image pushée: ${DOCKER_REGISTRY}/${APP_NAME}:latest"
                }
            }
        }

        // ========================================
        // BRANCHE NAS : Deploy + Tests + Rollback
        // ========================================
        stage('Pull image Nexus') {
            when { branch 'nas' }
            steps {
                echo "📥 Connexion et pull depuis Nexus..."
                script {
                    // Pull avec Docker Pipeline Plugin
                    docker.withRegistry("https://${DOCKER_REGISTRY}", 'nexus-credentials') {
                        def image = docker.image("${APP_NAME}:latest")
                        image.pull()

                        // Tag local pour usage
                        sh "docker tag ${DOCKER_REGISTRY}/${APP_NAME}:latest ${APP_NAME}:current"
                        echo "✅ Image pullée et taguée localement"
                    }
                }
            }
        }


        stage('Déploiement') {
            when { branch 'nas' }
            steps {
                echo "🚀 Déploiement/Mise à jour sur le NAS..."
                script {
                    // Connexion SSH au NAS et déploiement
                    withCredentials([sshUserPrivateKey(
                            credentialsId: 'NAS_KEY',           // identifiant interne Jenkins
                            keyFileVariable: 'SSH_KEY',         // le nom du fichier
                            usernameVariable: 'SSH_USER'        // le nom d'accès utilisateur
                    )]) {
                        sh '''

                            # Copie du docker-compose.yml (toujours nécessaire pour les changements de config)
                            scp -o StrictHostKeyChecking=no -i $SSH_KEY docker-compose.yml $SSH_USER@${NAS_SERVER}:/volume1/docker/file-storage-api/
                            
                            # Logique intelligente de déploiement
                            ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@${NAS_SERVER} "
                            
                                cd /volume1/docker/file-storage-api
                                   # Vérifier si la stack existe déjà
                                if docker stack ls --format '{{.Name}}' | grep -q '^file-storage$'; then
                                    echo 'Stack existe - Mise à jour en cours...\'
                                    
                                    # Mise à jour de la stack existante (rolling update)
                                    docker stack deploy -c docker-compose.yml file-storage
                                    
                                    echo 'Mise à jour terminée avec rolling update\'
                                else
                                    echo 'Première stack - Déploiement initial...\'
                                    
                                    # Premier déploiement
                                    docker stack deploy -c docker-compose.yml file-storage
                                    
                                    echo 'Déploiement initial terminé\'
                                fi
                                
                                # Vérification que les services sont en cours de démarrage
                                docker stack services file-storage
                                
                            "
                        '''
                    }
                }
            }
        }

        stage('Vérification déploiement') {
            when { branch 'nas' }
            steps {
                echo "✅ Vérification du déploiement..."
                script {
                    // Attente active du démarrage complet
                    timeout(time: 10, unit: 'MINUTES') {
                        retry(20) {
                            script {
                                def healthCheck = sh(
                                        script: "curl -f http://${NAS_SERVER}:${APP_PORT}/actuator/health",
                                        returnStatus: true
                                )
                                if (healthCheck != 0) {
                                    sleep(30)
                                    error("Service pas encore prêt")
                                }
                            }
                        }
                    }
                    echo "✅ Service opérationnel"
                }
            }
        }

        stage('Tests d\'intégration') {
            when { branch 'nas' }
            steps {
                echo "🔗 Exécution des tests d'intégration..."
                script {
                    try {
                        sh '''
                            # Tests d'intégration avec l'environnement réel
                            ./mvnw test -Dspring.profiles.active=integration
                        '''

                        publishTestResults testResultsPattern: 'target/failsafe-reports/*.xml'

                    } catch (Exception e) {
                        echo "❌ Tests d'intégration échoués : ${e.message}"
                        currentBuild.result = 'UNSTABLE'
                        error("Tests d'intégration échoués")
                    }
                }
            }
        }

        stage('Tests de régression') {
            when { branch 'nas' }
            steps {
                echo "🔍 Tests de régression..."
                script {
                    try {
                        sh '''
                            # Test de santé de l'application
                            curl -f http://${NAS_SERVER}:${APP_PORT}/actuator/health || exit 1
                            
                            # Test upload fichier
                            curl -X POST -F "file=@test-files/sample.png" \
                                 -F "project=test" \
                                 -H "Authorization: Bearer ${TEST_TOKEN}" \
                                 http://${NAS_SERVER}:${APP_PORT}/api/v1/files/upload || exit 1
                                 
                            echo "✅ Tests de régression réussis"
                        '''

                    } catch (Exception e) {
                        echo "❌ Tests de régression échoués : ${e.message}"
                        currentBuild.result = 'FAILURE'
                        error("Tests de régression échoués")
                    }
                }
            }
        }
    }

    // ========================================
    // GESTION DES ÉCHECS ET ROLLBACK
    // ========================================
    post {
        always {

            // Jenkins envoie le statut à GitHub
            step([$class: 'GitHubCommitStatusSetter'])

            // Nettoyage workspace
            cleanWs()
        }

        success {
            script {
                if (env.BRANCH_NAME == 'feature') {
                    echo "✅ Build feature réussi - Image pushée: ${DOCKER_REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
                } else if (env.BRANCH_NAME == 'nas') {
                    echo "✅ Déploiement NAS réussi - Version ${IMAGE_TAG} en ligne"

                    // Nettoyage des anciennes images de backup sur Jenkins
                    sh '''
                        docker image prune -f
                    '''
                }
            }
        }

        failure {
            script {
                if (env.BRANCH_NAME == 'nas') {
                    echo "💥 Déploiement échoué ! Rollback en cours..."

                    try {
                        withCredentials([sshUserPrivateKey(credentialsId: 'NAS_KEY', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                            sh '''
                                # Rollback via Docker Swarm
                                ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@${NAS_SERVER} "
                                    # Rollback natif Docker Swarm
                                    docker service rollback file-storage_file-storage-api
                                    
                                    # Vérification que le rollback fonctionne
                                    sleep 30
                                    curl -f http://localhost:${APP_PORT}/actuator/health
                                "
                            '''
                        }

                        echo "Rollback automatique réussi"

                        // Notification de rollback
                        emailext(
                                subject: "🔄 ROLLBACK - File Storage API (${IMAGE_TAG})",
                                body: "Le déploiement de ${IMAGE_TAG} a échoué. Rollback automatique effectué vers backup-${BUILD_NUMBER}.",
                                to: "${env.CHANGE_AUTHOR_EMAIL}"
                        )

                    } catch (Exception rollbackError) {
                        echo "💀 ERREUR CRITIQUE : Rollback échoué !"

                        // Arrêt d'urgence du service défaillant
                        try {
                            withCredentials([sshUserPrivateKey(credentialsId: 'NAS', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                                sh '''
                                    ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@${NAS_SERVER} \
                                    "docker service scale file-storage_file-storage-api=0"
                                '''
                            }
                            echo "Service arrêté en urgence"
                        } catch (Exception e) {
                            echo "Impossible d'arrêter le service - intervention manuelle requise"
                        }

                        // Notification critique
                        emailext(
                                subject: "🚨 URGENT - Rollback échoué File Storage API (${IMAGE_TAG})",
                                body: "Intervention manuelle requise ! Rollback automatique échoué pour ${IMAGE_TAG}.",
                                to: "${env.CHANGE_AUTHOR_EMAIL}"
                        )
                    }
                }
            }
        }

        unstable {
            // Si tests échouent mais build compile
            publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
            echo "⚠️ Build instable : tests échoués"
        }

    }
}