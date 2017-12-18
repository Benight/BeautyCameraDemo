//
//  TestViewController.m
//  BeautyCameraDemo
//
//  Created by 0o on 2017/12/14.
//  Copyright © 2017年 Benight. All rights reserved.
//

#import "TestViewController.h"
#import "BeautyCameraView.h"
#import <Masonry.h>

@interface TestViewController ()

@property (nonatomic, strong) BeautyCameraView *beautyCameraView;
@end

#define VideoAuthenticationSavePath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"VideoAuthentication.mp4"]

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.beautyCameraView = [[BeautyCameraView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) videoName:VideoAuthenticationSavePath cameraAspectRatio:CameraAspectRatio_aspectRatio];
    [self.view addSubview:self.beautyCameraView];
    
    [self configSlide];
}

- (void)configSlide {
    
    NSArray * array = [[NSArray alloc]initWithObjects:@"美颜程度",@"亮度",@"饱和度", nil];
    
    for (int i = 0; i < 3; i ++) {
        UISlider * slider = [[UISlider alloc]init];
        slider.maximumValue = 1;
        slider.minimumValue = 0;
        slider.value = 0.5;
        slider.tag = 100+i;
        [slider addTarget:self action:@selector(processSliderChange:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:slider];
        
        UILabel * label = [[UILabel alloc]init];
        label.text = array[i];
        label.layer.shadowColor = [UIColor blackColor].CGColor;
        label.layer.shadowOffset = CGSizeMake(3, 3);
        label.layer.shadowOpacity = 0.8;
        
        label.textColor = [UIColor whiteColor];
        [self.view addSubview:label];
        
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            
            make.bottom.equalTo(self.view).offset(-100-(i*40));
            make.width.equalTo(@100);
            make.height.equalTo(@30);
            make.left.equalTo(self.view).offset (15);
        }];
        
        [slider mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(self.view).offset(-150);
            make.height.equalTo(@40);
            make.left.equalTo(label.mas_right).offset(10);
            make.centerY.equalTo(label);
        }];
    }


}

- (void)processSliderChange:(UISlider *)slider {
    
    NSLog(@"%f",slider.value);
    NSLog(@"%ld",(long)slider.tag);
    if (slider.tag == 100) {
        self.beautyCameraView.intensity = slider.value;
    }else if (slider.tag == 101) {
        self.beautyCameraView.brightness = slider.value*2;
    }else if (slider.tag == 102) {
        self.beautyCameraView.saturation = slider.value*2;
    }
}


//翻转相机摄像头
- (IBAction)rotateCamera {

    [self.beautyCameraView rotateCamera];
}

//开始录制
- (IBAction)startRecord {

    [self.beautyCameraView startRecord];
}

//暂停录制
- (IBAction)pauseRecord:(id)sender {
    
    UIButton *button = sender;
    button.selected = !button.selected;
    if (button.selected) {
        [self.beautyCameraView pauseRecord];
    }else {
        [self.beautyCameraView resumeRecord];
    }
}

//重录
- (IBAction)retakeRecord {

    [self.beautyCameraView retakeRecord];
}

//结束录制
- (IBAction)stopRecordAndSave {

    [self.beautyCameraView stopRecordAndSave];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self.beautyCameraView removeFromSuperview];
//        self.beautyCameraView = nil;
//    });
}


@end
