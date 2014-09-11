//
//  ALTestingViewController.m
//  ALKMeanImageBGColor
//
//  Created by Alex Lee on 9/10/14.
//  Copyright (c) 2014 Alex Lee. All rights reserved.
//
//
// The MIT License (MIT)
//
// Copyright (c) 2014 alexlee002
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

#import "ALTestingViewController.h"
#import "UIImage+KMeanColor.h"

@interface ALImageColorCell : UITableViewCell

@end

@implementation ALImageColorCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
}

@end

@implementation ALTestingViewController
{
    NSArray             *_iconsUrl;
    NSMutableArray      *_images;
}

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        _iconsUrl = @[@"http://static.zhihu.com/static/favicon.ico",
                      @"http://www.apple.com/favicon.ico",
                      @"http://baidu.com/favicon.ico",
                      @"http://www.baidu.com/favicon.ico",
                      @"http://www.163.com/favicon.ico",
                      @"http://mat1.gtimg.com/www/icon/favicon2.ico",
                      @"http://www.sina.com.cn/favicon.ico",
                      @"http://news.ifeng.com/favicon.ico",
                      @"http://www.yahoo.com/favicon.ico",
                      @"http://www.cnn.com/favicon.ico"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self loadIcons];
    });
    
    [self.tableView registerClass:[ALImageColorCell class] forCellReuseIdentifier:@"icon_cells"];
}

#pragma mark -
- (void)loadIcons
{
    if (_images.count == 0) {
        _images = [NSMutableArray arrayWithCapacity:_iconsUrl.count];
        for (NSUInteger i = 0; i < _iconsUrl.count; ++i) {
            [_images addObject:[NSNull null]];
        }
    }
    for (NSUInteger i = 0; i < _images.count; ++i)  {
        id image = _images[i];
        if (image == [NSNull null]) {
            NSData *imgData = [NSData dataWithContentsOfURL:[NSURL URLWithString:_iconsUrl[i]]];
            if (imgData) {
                image = [UIImage imageWithData:imgData scale:[UIScreen mainScreen].scale];
                if (image) {
                    _images[i] = image;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateImageForCellAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                    });
                }
            }
        }
    }
}

- (void)updateImageForCellAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *visibleRows = [self.tableView indexPathsForVisibleRows];
    if (![visibleRows containsObject:indexPath]) {
        return;
    }
    if (_images[indexPath.row] == [NSNull null]) {
        return;
    }
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    CGFloat size = CGRectGetHeight(cell.contentView.bounds) - 4;
    UIView *accessoryView = [[UIView alloc] initWithFrame:CGRectMake(2, 2, size, size)];
    
    UIColor *bgcolor = [_images[indexPath.row] recommendedBgColor];
    CGFloat r, g, b;
    [bgcolor getRed:&r green:&g blue:&b alpha:nil];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"red:%.0f green:%.0f blue:%0.f", r * 0xFF, g * 0xFF, b * 0xFF];
    cell.detailTextLabel.textColor = bgcolor;
    
    accessoryView.backgroundColor = [bgcolor colorWithAlphaComponent:0.7];
    accessoryView.layer.borderColor = [UIColor blackColor].CGColor;
    accessoryView.layer.borderWidth = 1.f / [UIScreen mainScreen].scale;
    
    
    UIImageView *v = [[UIImageView alloc] initWithImage:_images[indexPath.row]];
    [accessoryView addSubview:v];
    v.center = CGPointMake(CGRectGetWidth(accessoryView.bounds) / 2, CGRectGetHeight(accessoryView.bounds) / 2);
    v.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin;
    
    cell.accessoryView = accessoryView;
    [cell setNeedsLayout];
}

#pragma mark - UITableView dataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSAssert(_images.count == _iconsUrl.count, @"images count not matches urls count!");
    return _iconsUrl.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"icon_cells" forIndexPath:indexPath];
    cell.textLabel.text = _iconsUrl[indexPath.row];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    id image = _images[indexPath.row];
    if (image != [NSNull null]) {
        [self updateImageForCellAtIndexPath:indexPath];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end
