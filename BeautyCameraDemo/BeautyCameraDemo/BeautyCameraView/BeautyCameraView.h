//
//  BeautyCameraView.h
//  BeautyCameraDemo
//
//  Created by 0o on 2017/12/14.
//  Copyright © 2017年 Benight. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, CameraAspectRatio) {

    CameraAspectRatio_square,   //1：1的正方形
    CameraAspectRatio_aspectRatio,  //原始的宽高比1280：720
};

@interface BeautyCameraView : UIView

- (instancetype)initWithFrame:(CGRect)frame videoName:(NSString *)videoName cameraAspectRatio:(CameraAspectRatio )cameraAspectRatio;

/** 美颜程度*/
@property (nonatomic, assign) CGFloat intensity;
/** 亮度*/
@property (nonatomic, assign) CGFloat brightness;
/** 饱和度*/
@property (nonatomic, assign) CGFloat saturation;

//翻转相机摄像头
- (void)rotateCamera;

//开始录制
- (void)startRecord;

//暂停录制
- (void)pauseRecord;

//继续录制
- (void)resumeRecord;

//重录
- (void)retakeRecord;

//结束录制
- (void)stopRecordAndSave;

//销毁
- (void)destructionCameraView;


@end
