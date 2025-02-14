# import package
Sys.setenv("JAVA_HOME" = "/Library/Java/JavaVirtualMachines/jdk-11.0.1.jdk/Contents/Home")
if(!require("rJava")) install.packages("rJava");library(rJava)
if(!require("dplyr")) install.packages("dplyr"); library(dplyr)
if(!require("DBI")) install.packages("DBI"); library(DBI)
if(!require("RJDBC")) install.packages("RJDBC"); library(RJDBC)
if(!require("stringr")) install.packages("stringr"); library(stringr)
if(!require("xlsx")) install.packages("xlsx"); library(xlsx)
if(!require("ggplot2")) install.packages("ggplot2"); library(ggplot2)
if(!require("lattice")) install.packages("lattice"); library(lattice)
if(!require("corrplot")) install.packages("corrplot"); library(corrplot)
if(!require("car")) install.packages("car"); library(car)
# 공분산성(vif)
if(!require("MASS")) install.packages("MASS"); library(MASS)
if(!require("nnet")) install.packages("nnet"); library(nnet)
# 다항형 로지스틱 회귀분석(multinum)
if(!require("fmsb")) install.packages("fmsb"); library(fmsb)
if(!require("cvTools"))install.packages("cvTools"); library(cvTools)
# 교차점겅(cvfolds)
if(!require("ROCR")) install.packages("ROCR"); library(ROCR)
# 분류정확도 그래프 
if(!require("rpart")) install.packages("rpart"); library(rpart)
if(!require("rpart.plot")) install.packages("rpart.plot"); library(rpart.plot)
if(!require("rattle")) install.packages("rattle"); library(rattle)
if(!require("randomForest")) install.packages("randomForest");library(randomForest)
if(!require("xgboost")) install.packages("xgboost");library(xgboost)
if(!require("e1071")) install.packages("e1071");library(e1071)

# db 연결
drv <- JDBC("oracle.jdbc.OracleDriver", "/Users/mac/Downloads/ojdbc6.jar")
con <- dbConnect(drv, "jdbc:oracle:thin:@//localhost:32769/xe", "scott", "tiger")
d1 <- dbGetQuery(con, "select * from european order by ROWN")
str(d1)


# 구단명, 시즌 분리
team <- unlist(str_replace_all(d1$TEAM, "\\([0-9]{2}_[0-9]{2}\\)", ""))
season <- unlist(str_extract(d1$TEAM, "[0-9]{2}_[0-9]{2}"))
d1$TEAM <- team
d1$SEASON <- season
View(d1)
dim(d1) # 522*40

# 변수 위치 조정
df <- d1[2:3]
df[3] <- d1[40]
df[4 :39] <- d1[4:39]
View(df)
str(df) # 522 39
dim(df)

# 데이터 표준화 / 정규화
# scale() = 표준화
# 정규화 nor = (x - min) / max - min
# 정규분포 확인 shapiro.test
# 정규성 검증 확인 사용자 정의 함수
check_standard <- function(x) {
  for (i in 1:38) {
    tryCatch({
      if(shapiro.test(x[,i])[[2]] >= 0.05){
        print(colnames(df)[i])
      }
    }, error = function(e){cat("Error :", colnames(df)[i],conditionMessage(e), "\n")})
  }
}
check_standard(df) # "SHOTS_CONCEDED"
# [해설] 독립변수들이 "SHOTS_CONCEDED"를 제외하고 정규성을 띄지 않기 때문에
#        정규화를 통해 값의 범위를 0 ~ 1 사이로 일치

# 정규화 사용자정의 함수
nor <- function(x) {
  re <- (x - min(x)) / max(x) - min(x)
  return(re)
}

# 독립변수(x) 정규화 
df[4:39] <- nor(df[4:39])

# 데이터 분류
# 1. 국가별 변수 만들기
# 522개 행 만들기
df$LEAGUE <- as.vector(runif(522, 1, 1))
# 빈 열 만들기
df$LEAGUE <- NA
df$LEAGUE[1:162] <- "Germany"
df$LEAGUE[163:342] <- "Spain"
df$LEAGUE[343:522] <- "England"

# 2. 순위 별
df <- df %>% mutate(RANK_C = ifelse(RANK <= 6, "Upper", "Lower"))
View(df)
dim(df)
# 변수정렬
df_f <- df[1]
df_f[2] <- df[41]
df_f[3] <- df[40]
df_f[4:41] <- df[2:39]
View(df_f)
write.xlsx(df_f, "scale_indiv_project.xlsx", sheetName = "Second", row.names = F)



# 데이터 확인
dim(df_f) # 522  41

# 이상치 제거
# 1. a, b 변수 생성 독립변수별 min, max추출
a <- NA;b <- NA
for (i in 1:length(df_num)) { 
  a[i] <- boxplot(df_num)$stats[,i][1]
  b[i] <- boxplot(df_num)$stats[,i][5]
  ab <- data.frame(a,b)
}

# 2. 이상치 제거
for (i in 1:36) {
  df_f <- df_f %>% filter(df_f[i+ 5] >= ab[i,1] & df_f[i + 5] <= ab[i,2])
}
table(df$RANK_C) # 360, 162
table(df_f$RANK_C) # 204, 51
boxplot(df_f[6:41])
str(df_f)
View(df_f)

# 비연속형 변수
# RANK, TEAM, SEASON, LEAGUE, RANK_C
# 연속형 변수
# LEAGUE, RANK_C, GOALS, SHOTS, YELLOW, RED, POSSESSION, PASS, AERIALWON, 
# SHOTS_CONCEDED, TACKLES, INTERCEPTIONS, FOULS, OFFSIDES, SHOTS_ON_TARGET, 
# DRIBBLES, FOULDED, OPEN_PLAY, COUNTER_ATTACK, SET_PIECE, PENALTY, OWN_GOAL, 
# CROSS, THROUGH_BALL, LONG_BALLS, SHORT_PASSES, LEFT_SIDE, MIDDLE_SIDE, 
# RIGHT_SIDE, SHOT_LEFT, SHOT_MIDDLE, SHOT_RIGHT, IN_6_YARD_BOX, IN_18_YARD_BOX
# OUTSIDE_OF_BOX, OWN_THIRD

# 범주형 변수 처리
df_f$RANK <- factor(df_f$RANK)
df_f$RANK_C <- factor(df_f$RANK_C)
df_f$LEAGUE <- factor(df_f$LEAGUE)

# 변수 간의 관계분석
# 1) 범주형 vs 범주형
tab1 <- table(df_f$RANK_C, df_f$LEAGUE)
tab1
#         England Germany Spain
# Lower      94      81    42
# Upper      17      21    15
ggplot(df_f, aes(x = RANK_C, fill = LEAGUE)) + geom_bar(position = "dodge")
ggplot(df_f, aes(x = RANK_C, fill = LEAGUE)) + geom_bar(position = "fill")
# [해석] Lower : England > Germany > Spain : 평준화 정도로 해석 가능
#        Upper : Germany > England > Spain : 평준화 정도로 해석 가능
# Why ? 이상치를 제거해서 엄청 잘하거나 못하는 기록을 가진 팀 제거!

# 상관행렬
df_f_cor <- cor(df_f[,6:41])
round(df_f_cor, 2)
corrplot(df_f_cor, 
         method = "shade",  # 숫자로 표현
         type = "upper",     # 색상 200개 선정
         order = "hclust",   # 왼쪽 아래 행렬만 표시
         addCoef.col = "black",  # 상관계수 색깔
         diag = F,
         number.cex = 0.5, 
         tl.cex = 0.5,
         addcolorlabel="no")





##############################################################################
################################# 추론 통계 ##################################
##############################################################################

# RANK(서열), RANK_C(범주, 2), LEAGUE(범주, 3)
# RANK <- 다항 로지스틱 회귀분석, dt, 앙상블 모형(R.F, XGboost)
# RANK_C <- 이항 로지스틱 회귀분석, dt, 앙상블 모형(R.F, XGboost)
# LEAGUE <- 다항 로지스틱 회구분석, dt, 앙상블 모형(R.F, XGboost)

# 사용할 Dataset subset
# TEAM, SEASON 제외
u_df <- df_f[,-c(4,5)]

####################################
### RANK 예측
####################################
# 1. 다항 로지스틱 회귀분석 (multinum)

# (1) 데이터 샘플링
idx <- sample(nrow(u_df), 0.7*nrow(u_df))
train <- u_df[idx,]
test  <- u_df[-idx,]

# (2) 회귀 모델 생성
mul_model <- multinom(RANK ~ ., train)
mul_model # 1,2위 예측 불가
vif(mul_model)

# (3) 회귀모델 예측치 생성
mul_pred <- predict(mul_model, test)

# (4) 모델평가 -> RANK 일정한 변수
mul_true <- test$RANK
mul_tab <- table(mul_true, mul_pred)
mul_tab

total <- 0
for (i in 1:20) {
  total <-  total + mul_tab[i,i]
}
acc <- total / sum(mul_tab)
acc # 0.1688312

mul_pr <- prediction(mul_pred, test$RANK)

# [해설] 예측률이 너무 낮다.

# 2. DT 

# (1) 데이터 샘플링
idx <- sample(nrow(u_df), 0.7*nrow(u_df))
train <- u_df[idx,]
test  <- u_df[-idx,]

# (2) 회귀 모델 생성
dt_model <- rpart(RANK ~ ., train)
dt_model # 1,2위 예측 불가
fancyRpartPlot(dt_model)

# (3) 회귀모델 예측치 생성
dt_pred <- predict(dt_model, test, type = "class")

# (4) 모델평가 -> RANK 일정한 변수
dt_true <- test$RANK
dt_tab <- table(dt_true, dt_pred)

total <- 0
for (i in 1:20) {
  total <-  total + dt_tab[i,i]
}
acc <- total / sum(dt_tab)
acc # 0.1688312 > 0.1948052
# [해설] 예측률이 너무 낮다. 그렇지만 로지스틱 회귀분석 보다는 높다.

# 3. randomForest
ntree <- 500
mtry <- round(sqrt(38))
mtry
# (1) 랜덤 포레스트 모델 생성
rf_model <- randomForest(RANK ~ ., u_df, ntree = ntree, mtry = mtry,
                         importance = T)

# (2) 중요 변수 확인
varImpPlot(rf_model)

# (3) 모델 평가
rf_pred <- rf_model$predicted
rf_true <- rf_model$y
rf_tab <- table(rf_true, rf_pred)
total <- 0
for (i in 1:20) {
  total <-  total + rf_tab[i,i]
}
acc <- total / sum(rf_tab)
acc # 0.1333333
# [해설] 3가지 모형중 가장 낮은 예측률을 보인다.
# [결론] 많은 수의 x변수를 상용했기 때문에 공분산성 확인이 필요

# 4. xgboost 다항 로지스틱 회귀분석 "multi:softmax"
str(u_df)

# (1) 변수조정 -> ??? 범주형 변수 ㅠㅠ
xg_df <- u_df[,-c(2,3)]
xg_df$RANK <- as.numeric(xg_df$RANK) - 1
# num_class = 20

# (2) train / test
idx <- sample(nrow(xg_df), 0.7*(nrow(xg_df)))
train <- xg_df[idx,]
test <- xg_df[-idx,]

# (3) xgb.dmatrix 생성
xg_dmatrix <- xgb.DMatrix(data = data.matrix(train[,-1]), label = train$RANK)

# (4) model 생성
xg_model <- xgboost(xg_dmatrix, max_depth = 2, eta = 1, nthread = 2,
                    nrounds = 2, objective = "multi:softmax", 
                    verbose = 0, num_class = 20)

# (5) 중요도 확인
import <- xgb.importance(colnames(train[,-1]), xg_model)
import
xgb.plot.importance(import)
# # Goal, short passes..

# (6) 예측도 확인
pred <- predict(xg_model, data.matrix(test[,-1]))
tab <- table(test[,1], pred)
tab

# 다항 분류 예측도 확인 사용자정의함수
mul_acc <- function(x){
  total <- 0
  for (i in 1:20) {
    total <-  total + x[i,i]
  }
  acc <- total / sum(x)
}
acc <- mul_acc(tab)
acc # 0.133758

# [해설] R.F보다는 다소 높은 예측률을 보이지만 다항 로지스틱이나 D.T보다는 낮다.

# 5. Naive Bayes 일고리즘(e1071)

# (1) train / test
na_idx <- sample(nrow(u_df), nrow(u_df) * 0.7)
na_train <- u_df[idx,]
na_test <- u_df[-idx,]

# (2) 분류모델생성
model <- naiveBayes(na_train[-1], na_train$RANK)
model

# (3) 분류모델 평가 : test data 
na_pred <- predict(model, na_test)
na_pred

# (4) 분류모델 평가
na_tab <- table(na_test$RANK, na_pred)
acc <- mul_acc(na_tab)
acc # 0.09395973

# [해설] Naive Bayes 모델은 가장 낮은 예측력을 보인다. 실제로 T.M에 더 적합한
#        알고리즘이다.
# So, 랭킹을 예측하기에는 너무 낮은 예측력을 보이므로 Rank_c를 예측!

####################################
### RANK_C 예측
####################################
# 1. 이항 로지스틱 회귀분석(glm)

# (1) 데이터 샘프링
idx <- sample(nrow(u_df), nrow(u_df)*0.7)
train <- u_df[idx,-1]
test  <- u_df[-idx,-1]
table(u_df$RANK_C)
# (2) 분류모델 생성
model <- glm(RANK_C ~ ., train, family = "binomial")
model

# (3) 예측치 생성
pred <- predict(model, newdata = test, type = "response")
pred

# (3) 1. cut off = 0.5
pred <- ifelse(pred >= 0.5, 1, 0)
table(pred)

tab  <- table(test$RANK_C, pred)
tab

# (4) 예측률 y 변수 비율이 동일 x -> F1_score
recall <- (tab[2,2]) / (tab[2,1] + tab[2,2])
precision <- tab[2,2] / (tab[1,2] + tab[2,2])
f1_score <- 2*((recall*precision) / (recall + precision))
f1_score # 0.7948718

# 2. DT
# (1) 분류 모델
dt_model <- rpart(RANK_C ~ ., train)
prp(dt_model)
fancyRpartPlot(dt_model)

# (2) 예측
dt_pred2 <- predict(dt_model, test, type = "class")

# (3) 분류모델 평가
dt_tab2 <- table(test$RANK_C, dt_pred2)
dt_tab2
recall <- (dt_tab2[2,2]) / (dt_tab2[2,1] + dt_tab2[2,2])
precision <- dt_tab2[2,2] / (dt_tab2[1,2] + dt_tab2[2,2])
f1_score <- 2*((recall*precision) / (recall + precision))
f1_score # 0.725
# [해설] 로지스틱 회귀분석(0.7948718) 보다는 낮다.

# 3. randomForest
ntree <- 500
mtry <- round(sqrt(37))
mtry
# (1) 랜덤 포레스트 모델 생성
rf_model <- randomForest(RANK_C ~ ., u_df[-1], ntree = ntree, mtry = mtry,
                         importance = T)

# (2) 중요 변수 확인
varImpPlot(rf_model)

# (3) 모델 평가
rf_pred <- rf_model$predicted
rf_true <- rf_model$y
rf_tab <- table(rf_true, rf_pred)
recall <- (rf_tab[2,2]) / (rf_tab[2,1] + rf_tab[2,2])
precision <- rf_tab[2,2] / (rf_tab[1,2] + rf_tab[2,2])
f1_score <- 2*((recall*precision) / (recall + precision))
f1_score # 0.8441558
# [해설] 이전 모델보다 앙상읍ㄹ 모형이 더 높은 예측력을 보인다.

# 4. XGboost
train$RANK_C <- as.character(train$RANK_C)
train$RANK_C <- ifelse(train$RANK_C == "Lower", 0 ,1)
test$RANK_C <- as.character(test$RANK_C)
test$RANK_C <- ifelse(test$RANK_C == "Lower", 0 ,1)
# (1) XGboost matrix 생성 
View(train)
dtrain <- xgb.DMatrix(data = data.matrix(train[-1]), label = train$RANK_C)
dtrain

# (2) 모델생성
xgb_model <- xgboost(dtrain, max_depth = 2, eta = 1, nthread = 2, nrounds = 2,
                     objective = "binary:logistic", verbose = 0)
# (3) 변수 영향력 확인
import <- xgb.importance(colnames(test[-1]), xgb_model)
import
xgb.plot.importance(import)

# (4) 예측력 확인
pred <- predict(xgb_model, data.matrix(test[-1]))
pred <- ifelse(pred >= 0.5, 1, 0)
tab <- table(test$RANK_C, pred)
tab
recall <- (tab[2,2]) / (tab[2,1] + tab[2,2])
precision <- tab[2,2] / (tab[1,2] + tab[2,2])
f1_score <- 2*((recall*precision) / (recall + precision))
f1_score # 0.7733333
# [해설] 모델중 가장낮은 예측력을 보인다.


#############################################################################
# 최종 수정 data.frame DB 전송
dbWriteTable(con, name = "f_eruopean", value = df_f) 


# DB 연결 종료 
dbDisconnect(con) 