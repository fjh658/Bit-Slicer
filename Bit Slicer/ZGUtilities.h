/*
 * Created by Mayur Pawashe on 5/12/11.
 *
 * Copyright (c) 2012 zgcoder
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * Neither the name of the project's author nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "ZGMemoryTypes.h"
#import "ZGVariable.h"
#import "ZGSearchData.h"
#import "ZGSearchFunctions.h"

#ifdef _DEBUG
	#define ZG_LOG(format, ...) NSLog(format, __VA_ARGS__)
#else
	#define ZG_LOG(format, ...) do { } while (0)
#endif

ZGMemoryAddress ZGMemoryAddressFromExpression(NSString *expression);
BOOL ZGIsValidNumber(NSString *expression);

BOOL ZGIsNumericalDataType(ZGVariableType dataType);
ZGMemorySize ZGDataSizeFromNumericalDataType(BOOL isProcess64Bit, ZGVariableType dataType);

void *ZGValueFromString(BOOL isProcess64Bit, NSString *stringValue, ZGVariableType dataType, ZGMemorySize *dataSize);
ZGMemorySize ZGDataAlignment(BOOL isProcess64Bit, ZGVariableType dataType, ZGMemorySize dataSize);

unsigned char *ZGAllocateFlagsForByteArrayWildcards(NSString *searchValue);