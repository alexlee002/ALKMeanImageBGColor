//
//  UIImage+KMeanColor.m
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

#import "UIImage+KMeanColor.h"

@interface KMeanImageSampler : NSObject
- (NSInteger)sampleWithWidth:(NSInteger)width height:(NSInteger)height;
@end

@interface RandomSampler : KMeanImageSampler

@end

@interface GridSampler : KMeanImageSampler
{
    @private
    NSInteger _calls;
}
@end


// RGBA KMean Constants
const uint32_t kNumberOfClusters = 4;
const int kNumberOfIterations = 50;
const uint32_t kMaxBrightness = 600;
const uint32_t kMinDarkness = 100;

#define kDefaultBgColor [UIColor whiteColor]


@interface KMeanCluster : NSObject

@end
@implementation KMeanCluster
{
    uint8_t     _centroid[3];
    uint32_t    _aggregate[3];
    uint32_t    _counter;
    uint32_t    _weight;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (void)reset
{
    _centroid[0] = _centroid[1] = _centroid[2] = 0;
    _aggregate[0] = _aggregate[1] = _aggregate[2] = 0;
    _counter = 0;
    _weight = 0;
}
- (void)setCentroidWithRed:(uint8_t)r green:(uint8_t)g blue:(uint8_t)b
{
    _centroid[0] = r;
    _centroid[1] = g;
    _centroid[2] = b;
}

- (void)getCentroidWithRed:(uint8_t *)r green:(uint8_t *)g blue:(uint8_t *)b
{
    *r = _centroid[0];
    *g = _centroid[1];
    *b = _centroid[2];
}

- (BOOL)isAtCentroidWithRed:(uint8_t)r green:(uint8_t)g blue:(uint8_t)b
{
    return r == _centroid[0] && g == _centroid[1] && b == _centroid[2];
}

- (void)recomputeCentroid {
    if (_counter > 0) {
        _centroid[0] = _aggregate[0] / _counter;
        _centroid[1] = _aggregate[1] / _counter;
        _centroid[2] = _aggregate[2] / _counter;
        
        _aggregate[0] = _aggregate[1] = _aggregate[2] = 0;
        _weight = _counter;
        _counter = 0;
    }
}

- (void)addPointWithRed:(uint8_t)r green:(uint8_t)g blue:(uint8_t)b
{
    _aggregate[0] += r;
    _aggregate[1] += g;
    _aggregate[2] += b;
    ++_counter;
}

- (uint32_t)getDistanceSqrWithRed:(uint8_t)r green:(uint8_t)g blue:(uint8_t)b
{
    return (r - _centroid[0]) * (r - _centroid[0]) +
    (g - _centroid[1]) * (g - _centroid[1]) +
    (b - _centroid[2]) * (b - _centroid[2]);
}

- (BOOL)compareCentroidWithAggregate {
    if (_counter == 0)
        return NO;
    
    return _aggregate[0] / _counter == _centroid[0] &&
    _aggregate[1] / _counter == _centroid[1] &&
    _aggregate[2] / _counter == _centroid[2];
}

- (uint32_t)weight
{
    return _weight;
}

@end


@implementation KMeanImageSampler
- (NSInteger)sampleWithWidth:(NSInteger)width height:(NSInteger)height
{
    return 0;
}
@end

@implementation RandomSampler

- (NSInteger)sampleWithWidth:(NSInteger)width height:(NSInteger)height
{
    return random();
}

@end

@implementation GridSampler

- (instancetype)init
{
    self = [super init];
    if (self) {
        _calls = 0;
    }
    return self;
}

- (NSInteger)sampleWithWidth:(NSInteger)width height:(NSInteger)height
{
    _calls ++;
    return (width * height * _calls / kNumberOfClusters) % (width * height) +
    _calls / kNumberOfClusters;
}

@end


static int kBytesPerPixel = 4;
static int kBitsPerComponent = 8;

@implementation UIImage (KMeanColor)
- (UIColor *)recommendedBgColor
{
    RandomSampler *sampler = [[RandomSampler alloc] init];
    return [self rcommendedBgColorWithSampler:sampler];
}


/*!
 * @see: https://github.com/adobe/chromium/blob/master/ui/gfx/color_analysis.cc
 */
- (UIColor *)rcommendedBgColorWithSampler:(KMeanImageSampler *)sampler
{
    UIColor *color = kDefaultBgColor;
    UIImage *originalImage = self;
    if (self.scale > 1.f) {
        originalImage = [UIImage imageWithCGImage:self.CGImage scale:1 orientation:self.imageOrientation];
    }
    CGSize imageSize = originalImage.size;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned int bitmapLength = imageSize.width * imageSize.height * kBytesPerPixel;
    UInt8 *bitmap = (UInt8 *)malloc(bitmapLength);
    memset(bitmap, 0x00, bitmapLength);
    
    int bytesPerRow = kBytesPerPixel * imageSize.width;
    
    CGContextRef context = CGBitmapContextCreate(bitmap, imageSize.width, imageSize.height, kBitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, CGRectMake(0, 0, imageSize.width, imageSize.height), originalImage.CGImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    NSMutableArray *clusters = [NSMutableArray arrayWithCapacity:kNumberOfClusters];
    for (NSInteger i = 0; i < kNumberOfClusters; ++i) {
        clusters[i] = [[KMeanCluster alloc] init];
    }
    
    // Pick a starting point for each cluster
    NSInteger k = 0;
    while ( k < clusters.count) {
        KMeanCluster *cluster = clusters[k];
        
        // Try up to 10 times to find a unique color. If no unique color can be
        // found, destroy this cluster.
        BOOL isUniqueColor = NO;
        for (NSInteger i = 0; i < 10; ++i) {
            NSInteger pixelPos = [sampler sampleWithWidth:imageSize.width height:imageSize.height] % ((NSInteger)imageSize.width * (NSInteger)imageSize.height);
            UInt8 r = bitmap[pixelPos * 4];
            UInt8 g = bitmap[pixelPos * 4 + 1];
            UInt8 b = bitmap[pixelPos * 4 + 2];
            
            // Loop through the previous clusters and check to see if we have seen
            // this color before.
            isUniqueColor = YES;
            for (NSInteger j = 0; clusters[j] != cluster; ++j) {
                if ([clusters[j] isAtCentroidWithRed:r green:g blue:b]) {
                    isUniqueColor = NO;
                    break;
                }
            }
            // If we have a unique color set the center of the cluster to
            // that color.
            if (isUniqueColor) {
                [cluster setCentroidWithRed:r green:g blue:b];
                break;
            }
        }
        
        // If we don't have a unique color erase this cluster.
        if (!isUniqueColor) {
            [clusters removeObjectAtIndex:k];
        } else {
            // Have to increment the iterator here, otherwise the increment in the
            // for loop will skip a cluster due to the erase if the color wasn't
            // unique.
            ++k;
        }
        
        BOOL convergence = NO;
        for (NSInteger iteration = 0;
             iteration < kNumberOfIterations && !convergence && clusters.count > 0;
             ++iteration) {
            // Loop through each pixel so we can place it in the appropriate cluster.
            NSUInteger p = 0;
            while (p < bitmapLength) {
                UInt8 r = bitmap[p++];
                if (r == bitmapLength) {
                    continue;
                }
                UInt8 g = bitmap[p++];
                if (p == bitmapLength) {
                    continue;
                }
                UInt8 b = bitmap[p++];
                if (b == bitmapLength) {
                    continue;
                }
                ++p; // Ignore the alpha channel.
                
                UInt32 distanceSqrToClosestCluster = UINT32_MAX;
                KMeanCluster *closestCluster = clusters.firstObject;
                
                // Figure out which cluster this color is closest to in RGB space.
                for (NSUInteger i = 0; i < clusters.count; ++i) {
                    KMeanCluster *cluster = clusters[i];
                    UInt32 distanceSqr = [cluster getDistanceSqrWithRed:r green:g blue:b];
                    if (distanceSqr < distanceSqrToClosestCluster) {
                        distanceSqrToClosestCluster = distanceSqr;
                        closestCluster = cluster;
                    }
                }
                [closestCluster addPointWithRed:r green:g blue:b];
            }
            
            // Calculate the new cluster centers and see if we've converged or not.
            convergence = YES;
            for (NSUInteger i = 0; i < clusters.count; ++i) {
                KMeanCluster *cluster = clusters[i];
                convergence &= [cluster compareCentroidWithAggregate];
                
                [cluster recomputeCentroid];
            }
        }
        
        // Sort the clusters by population so we can tell what the most popular
        // color is.
        [clusters sortUsingComparator:^NSComparisonResult(KMeanCluster *a, KMeanCluster *b) {
            return a.weight > b.weight ? NSOrderedAscending : (a.weight == b.weight ? NSOrderedSame : NSOrderedDescending);
        }];
        
        // Loop through the clusters to figure out which cluster has an appropriate
        // color. Skip any that are too bright/dark and go in order of weight.
        for (NSUInteger i = 0; i < clusters.count; ++i) {
            KMeanCluster *cluster = clusters[i];
            UInt8 r, g, b;
            [cluster getCentroidWithRed:&r green:&g blue:&b];
            // Sum the RGB components to determine if the color is too bright or too
            // dark.
            UInt32 summedColor = r + g + b;
            if (summedColor < kMaxBrightness && summedColor > kMinDarkness) {
                // If we found a valid color just set it and break. We don't want to
                // check the other ones.
                color = [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
                break;
            } else if (cluster == clusters.firstObject) {
                // We haven't found a valid color, but we are at the first color so
                // set the color anyway to make sure we at least have a value here.
                color = [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
            }
        }
    }
    free(bitmap);
    return color;
}

@end
