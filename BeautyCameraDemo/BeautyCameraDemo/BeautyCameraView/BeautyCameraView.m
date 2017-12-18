//
//  BeautyCameraView.m
//  BeautyCameraDemo
//
//  Created by 0o on 2017/12/14.
//  Copyright © 2017年 Benight. All rights reserved.
//

#import "BeautyCameraView.h"
#import <GPUImage/GPUImage.h>
#import "GPUImageBeautifyFilter.h"
#import <Photos/Photos.h>
#import "GPUImageMovieWriterEx.h"

#define VideoAuthenticationSavePath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"VideoAuthentication.mp4"]

typedef NS_ENUM(NSInteger, CameraRecordState) {

    CameraRecordState_start, //开始录制;
    CameraRecordState_pause,  //暂停录制;
    CameraRecordState_stop, //结束录制;
};


@interface BeautyCameraView ()  <GPUImageVideoCameraDelegate, UIGestureRecognizerDelegate>

{

    CGFloat _wight;
    CGFloat _height;
    CameraAspectRatio _kCameraAspectRatio;
}

@property (nonatomic, strong ) GPUImageVideoCamera    *videoCamera;//相机
@property (nonatomic, strong ) GPUImageBeautifyFilter *beautifyFilter;//美颜滤镜
@property (nonatomic, strong ) GPUImageCropFilter     *cropFliter;//剪切滤镜
@property (nonatomic, strong ) GPUImageMovieWriterEx  *movieWriter;//存储
@property (nonatomic, strong ) GPUImageView           *filterView;//预览视图
@property (nonatomic, strong ) GPUImageFilterGroup    *filterGroup;//滤镜组

@property (nonatomic, strong ) UIView                 *gestureView;//手势视图
@property (nonatomic, assign ) CGFloat                beginGestureScale;//开始的缩放比例
@property (nonatomic, assign ) CGFloat                effectiveScale;//最后的缩放比例
@property (nonatomic, strong ) CALayer                *focusLayer;//聚焦层

@property (nonatomic, strong ) NSString               *videoName;
@property (nonatomic, strong ) NSURL                  *movieURL;//存储地址

@property (nonatomic, assign ) CameraRecordState      cameraRecordState; //录制状态
/** 用来判断权限*/
@property (nonatomic, assign ) BOOL                   isAuthorised;


@end

@implementation BeautyCameraView

- (instancetype)initWithFrame:(CGRect)frame videoName:(NSString *)videoName cameraAspectRatio:(CameraAspectRatio )cameraAspectRatio
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        _wight = self.bounds.size.width;
        _height = self.bounds.size.height;
        _kCameraAspectRatio = cameraAspectRatio;
        self.cameraRecordState = CameraRecordState_stop;
        
        if (!self.videoName.length) {
            self.videoName = VideoAuthenticationSavePath;
        }
        
        [self videoAuthAction];

    }
    return self;
}

- (void)videoAuthAction {
    
    __weak typeof(self) weakSelf = self;
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.isAuthorised = granted;
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.isAuthorised = YES;
                [strongSelf configCamera];
                [strongSelf.videoCamera startCameraCapture];
            });
        }else {
        
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }
    }];
}
- (void)configCamera {
    
    [self.videoCamera removeAllTargets];
    [self addSubview:self.filterView];
    
    [self.filterGroup addTarget:self.cropFliter];
    [self.filterGroup addTarget:self.beautifyFilter];
    [self.cropFliter addTarget:self.beautifyFilter];
    
    [self.filterGroup setInitialFilters:[NSArray arrayWithObject:self.cropFliter]];
    [self.filterGroup setTerminalFilter:self.beautifyFilter];
    [self.filterGroup useNextFrameForImageCapture];
    [self.filterGroup addTarget:self.filterView];
    
    [self.videoCamera addTarget:self.filterGroup];
    
    [self configfocusImage:[UIImage imageNamed:@"foces_white"]];
    
    self.videoCamera.captureSessionPreset =  AVCaptureSessionPreset1280x720;
    
    //控制正方形的地方有两个，一个是剪切滤镜，还有一个是写滤镜
    if (_kCameraAspectRatio == CameraAspectRatio_square) {
        self.cropFliter.cropRegion = CGRectMake(0.0, (1280-720)/2/1280.0, 1.0, 720.0/1280.0f);
    }else {
        self.cropFliter.cropRegion = CGRectMake(0.0, 0.0, 1.0, 1.0);
    }
    self.filterView.frame = self.bounds;
    [self.filterGroup forceProcessingAtSize:self.bounds.size];
    self.gestureView.frame = self.bounds;
}


/** 翻转相机摄像头*/
- (void)rotateCamera {
    
    if (!self.isAuthorised) {
        return;
    }
    [self.videoCamera rotateCamera];
}

/** 开始录制*/
- (void)startRecord {
    
    if (!self.isAuthorised) {
        return;
    }
    if (self.cameraRecordState == CameraRecordState_stop) {
        [self.filterGroup addTarget:self.movieWriter];
        self.videoCamera.audioEncodingTarget = self.movieWriter;
        [self.movieWriter startRecording];
        self.cameraRecordState = CameraRecordState_start;
    }
}

/** 继续录制*/
- (void)resumeRecord {
    if (!self.isAuthorised) {
        return;
    }
    if (self.cameraRecordState == CameraRecordState_pause) {
        [self.movieWriter resumeRecording];
        self.cameraRecordState = CameraRecordState_start;
    }
}

/** 暂停录制*/
- (void)pauseRecord {
    if (!self.isAuthorised) {
        return;
    }
    if (self.cameraRecordState == CameraRecordState_start) {
        [self.movieWriter pauseRecording];
        self.cameraRecordState = CameraRecordState_pause;

    }
}

/** 重录*/
- (void)retakeRecord {
    
    if (!self.isAuthorised) {
        return;
    }
    if (self.cameraRecordState != CameraRecordState_stop) {
        [self.movieWriter pauseRecording];
        
        [self.beautifyFilter removeTarget:self.movieWriter];
        self.videoCamera.audioEncodingTarget = nil;
        [self.movieWriter cancelRecording];
        self.movieWriter = nil;
        self.cameraRecordState = CameraRecordState_stop;
    }

}

/** 结束录制*/
- (void)stopRecordAndSave {
    
    
    if (!self.isAuthorised) {
        return;
    }

    if (self.cameraRecordState != CameraRecordState_stop) {
        //录制的视频存在沙盒
//        [self stopSaveNSCachesDirectory];
        
        //录制的视频存在相册
        [self stopSavePHPhotoLibrary];
    }

}

//录制的视频存在沙盒
- (void)stopSaveNSCachesDirectory {

    [self.filterGroup removeTarget:self.movieWriter];
    self.videoCamera.audioEncodingTarget = nil;

    __weak typeof(self) weakSelf = self;
    [self.movieWriter finishRecordingWithCompletionHandler:^{
        __strong  typeof(self) strongSelf = weakSelf;

        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.movieWriter = nil;
            strongSelf.cameraRecordState = CameraRecordState_stop;
        });
    }];
}

//录制的视频存在相册
- (void)stopSavePHPhotoLibrary {
    
    [self.beautifyFilter removeTarget:self.movieWriter];
    self.videoCamera.audioEncodingTarget = nil;
    [self.movieWriter finishRecording];
    self.movieWriter = nil;

    
    NSLog(@"Movie completed");
    [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {

        if ( [PHAssetCreationRequest class] ) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypeVideo fileURL:self.movieURL options:nil];
            } completionHandler:^( BOOL success, NSError *error ) {
                self.cameraRecordState = CameraRecordState_stop;

                if ( ! success ) {
                    NSLog( @"Error : %@", error );
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[[UIAlertView alloc] initWithTitle:@""
                                                    message:@"保存失败"
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil] show];
                    });
                    
                }else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        [[[UIAlertView alloc] initWithTitle:@""
                                                    message:@"保存成功"
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil] show];
                    });
                    
                }
            }];
        }
    }];
}


#pragma mark - seter && getter
- (GPUImageBeautifyFilter *)beautifyFilter {
    
    if (!_beautifyFilter) {
        _beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
    }
    return _beautifyFilter;
}

- (GPUImageMovieWriterEx *)movieWriter {
    
    if (!_movieWriter) {
        CGSize outputSize = CGSizeZero;
        if (_kCameraAspectRatio == CameraAspectRatio_square) {
            outputSize = CGSizeMake(_wight *2, _wight*2);
        }else {
            outputSize = CGSizeMake(_wight*2, _height*2);
        }
        unlink([self.videoName UTF8String]);
        self.movieURL = [NSURL fileURLWithPath:self.videoName];
        
        _movieWriter = [[GPUImageMovieWriterEx alloc] initWithMovieURL:self.movieURL size:outputSize fileType:AVFileTypeMPEG4 outputSettings:nil];//GPUImageDEMO里用的AVFileTypeQuickTimeMovie，这个会使安卓不显示不了，所以用AVFileTypeMPEG4
        _movieWriter.assetWriter.movieFragmentInterval = kCMTimeInvalid;
        _movieWriter.encodingLiveVideo = YES;
    }
    return _movieWriter;
}

- (GPUImageVideoCamera *)videoCamera {
    
    if (!_videoCamera) {
        _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
        
        //该句可防止允许声音通过的情况下，避免录制第一帧黑屏闪屏(====)
        [_videoCamera addAudioInputsAndOutputs];
    }
    return _videoCamera;
}

- (GPUImageCropFilter *)cropFliter {
    
    if (!_cropFliter) {
        _cropFliter = [[GPUImageCropFilter alloc] init];
    }
    return _cropFliter;
}

- (GPUImageView *)filterView {
    
    if (!_filterView) {
        _filterView = [[GPUImageView alloc] init];
        //    _filterView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
        _filterView.clipsToBounds = YES;
    }
    return _filterView;
}

- (GPUImageFilterGroup *)filterGroup {
    
    if (!_filterGroup) {
        _filterGroup = [[GPUImageFilterGroup alloc]init];
    }
    return _filterGroup;
}

- (UIView *)gestureView {
    
    if (!_gestureView) {
        _gestureView = [[UIView alloc]init];
        _gestureView.backgroundColor = [UIColor clearColor];
        [self.filterView addSubview:_gestureView];
    }
    return _gestureView;
}

- (void)setIntensity:(CGFloat)intensity {

    _intensity = intensity;
    self.beautifyFilter.intensity = intensity;
}

- (void)setBrightness:(CGFloat)brightness {

    _brightness = brightness;
    self.beautifyFilter.brightness = brightness;
}

- (void)setSaturation:(CGFloat)saturation {

    _saturation = saturation;
    self.beautifyFilter.saturation = saturation;
}

#pragma mark - 相机焦距&&放大缩小
//设置聚焦图片
- (void)configfocusImage:(UIImage *)focusImage {
    if (!focusImage) return;
    
    if (!_focusLayer) {
        //增加tap手势，用于聚焦及曝光
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusFunction:)];
        [self.gestureView addGestureRecognizer:tap];
        //增加pinch手势，用于调整焦距
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(focusDisdance:)];
        [self.gestureView addGestureRecognizer:pinch];
        pinch.delegate = self;
    }
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, focusImage.size.width, focusImage.size.height)];
    imageView.image = focusImage;
    CALayer *layer = imageView.layer;
    layer.hidden = YES;
    [self.gestureView.layer addSublayer:layer];
    _focusLayer = layer;
    
}

//对焦方法
- (void)focusFunction:(UITapGestureRecognizer *)tap {
    self.gestureView.userInteractionEnabled = NO;
    CGPoint touchPoint = [tap locationInView:tap.view];
    // CGContextRef *touchContext = UIGraphicsGetCurrentContext();
    [self layerAnimationWithPoint:touchPoint];
    
    if(_videoCamera.cameraPosition == AVCaptureDevicePositionBack){
        touchPoint = CGPointMake( touchPoint.y /tap.view.bounds.size.height ,1-touchPoint.x/tap.view.bounds.size.width);
    }
    else
        touchPoint = CGPointMake(touchPoint.y /tap.view.bounds.size.height ,touchPoint.x/tap.view.bounds.size.width);
    
    if([self.videoCamera.inputCamera isExposurePointOfInterestSupported] && [self.videoCamera.inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
    {
        NSError *error;
        if ([self.videoCamera.inputCamera lockForConfiguration:&error]) {
            [self.videoCamera.inputCamera setExposurePointOfInterest:touchPoint];
            [self.videoCamera.inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            if ([self.videoCamera.inputCamera isFocusPointOfInterestSupported] && [self.videoCamera.inputCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                [self.videoCamera.inputCamera setFocusPointOfInterest:touchPoint];
                [self.videoCamera.inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
            }
            [self.videoCamera.inputCamera unlockForConfiguration];
        } else {
            NSLog(@"ERROR = %@", error);
        }
    }
}

//对焦动画
- (void)layerAnimationWithPoint:(CGPoint)point {
    if (_focusLayer) {
        ///聚焦点聚焦动画设置
        CALayer *foLayer = _focusLayer;
        foLayer.hidden = NO;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [foLayer setPosition:point];
        foLayer.transform = CATransform3DMakeScale(2.0f,2.0f,1.0f);
        [CATransaction commit];
        
        CABasicAnimation *animation = [ CABasicAnimation animationWithKeyPath: @"transform" ];
        animation.toValue = [ NSValue valueWithCATransform3D: CATransform3DMakeScale(1.0f,1.0f,1.0f)];
        animation.delegate = self;
        animation.duration = 0.3f;
        animation.repeatCount = 1;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [foLayer addAnimation: animation forKey:@"animation"];
    }
}

//动画的delegate方法
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    //1秒钟延时
    [self performSelector:@selector(focusLayerNormal) withObject:self afterDelay:0.5f];
}

//focusLayer回到初始化状态
- (void)focusLayerNormal {
    self.gestureView.userInteractionEnabled = YES;
    _focusLayer.hidden = YES;
}

//调整焦距方法
-(void)focusDisdance:(UIPinchGestureRecognizer*)pinch {
    self.effectiveScale = self.beginGestureScale * pinch.scale;
    if (self.effectiveScale < 1.0f) {
        self.effectiveScale = 1.0f;
    }
    CGFloat maxScaleAndCropFactor = 3.0f;//设置最大放大倍数为3倍
    if (self.effectiveScale > maxScaleAndCropFactor)
        self.effectiveScale = maxScaleAndCropFactor;
    [CATransaction begin];
    [CATransaction setAnimationDuration:.025];
    NSError *error;
    if([self.videoCamera.inputCamera lockForConfiguration:&error]){
        [self.videoCamera.inputCamera setVideoZoomFactor:self.effectiveScale];
        [self.videoCamera.inputCamera unlockForConfiguration];
    }
    else {
        NSLog(@"ERROR = %@", error);
    }
    
    [CATransaction commit];
}

//手势代理方法
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
        self.beginGestureScale = self.effectiveScale;
    }
    return YES;
}

//销毁
- (void)destructionCameraView {
    
    [self.videoCamera stopCameraCapture];
    [self.videoCamera removeAllTargets];
    [self.filterGroup removeAllTargets];
    
    self.videoCamera = nil;
}

- (void)dealloc {

    NSLog(@"BeautyCameraView--dealloc");
}
@end
