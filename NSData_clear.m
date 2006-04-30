/*
 * Copyright � 2003,2006, Bryan L Blackburn.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. Neither the names Bryan L Blackburn, Withay.com, nor the names of
 *    any contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRYAN L BLACKBURN ``AS IS'' AND ANY
 * EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
/* NSData_clear.m */

#import "NSData_clear.h"
#include <objc/objc-runtime.h>

@implementation NSData (withay_clear)

/* 
 * Warning: massive hack ahead, but it gets the job done, at least for now...
 */
- (void) clearOutData
{
   if( [ self isKindOfClass:NSClassFromString( @"NSConcreteData" ) ] ||
       [ self isKindOfClass:NSClassFromString( @"NSConcreteMutableData" ) ] )
   {
      BOOL isMutable;
      if( [ self isKindOfClass:NSClassFromString( @"NSConcreteData" ) ] )
         isMutable = NO;
      else
         isMutable = YES;
      char *someData = NULL;
      int index;
      for( index = 0; index < isa->ivars->ivar_count; index++ )
      {
         Ivar ivar = &isa->ivars->ivar_list[ index ];
         if( strcmp( ivar->ivar_name, "_bytes" ) == 0 )
         {
            if( isMutable )
               someData = *( (char **) ( (char *) self + ivar->ivar_offset ) );
            else
               someData = ( (char *) self + ivar->ivar_offset );
         }
      }
      if( someData != NULL )   // We found _bytes
      {
         int length = [ self length ];
         for( index = 0; index < length; index++ )
            someData[ index ] = 0;
      }
      else
         NSLog( @"NSData_clear: warning, couldn't find _bytes\n" );
   }
   else
      NSLog( @"NSData_clear: warning, can't clear class %@\n", NSStringFromClass( [ self class ] ) );
}

@end
