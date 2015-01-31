//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//! @file       _mach_lcstr.h
//!
//! @author     D.V.
//! @copyright  Copyright (c) 2014-2015 D.V. All rights reserved.
//|
//| Permission is hereby granted, free of charge, to any person obtaining a
//| copy of this software and associated documentation files (the "Software"),
//| to deal in the Software without restriction, including without limitation
//| the rights to use, copy, modify, merge, publish, distribute, sublicense,
//| and/or sell copies of the Software, and to permit persons to whom the
//| Software is furnished to do so, subject to the following conditions:
//|
//| The above copyright notice and this permission notice shall be included
//| in all copies or substantial portions of the Software.
//|
//| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//| OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//| MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//| IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//| CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//| TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//| SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------------//

#ifndef __mach_lcstr_h
#define __mach_lcstr_h

//! Copies the contents of \a source_str from the source load command into
//! the destination load command, updating \a dest_lc with the correct
//! offset.
//!
//! @return
//! The number of bytes copied.
_mk_internal_extern size_t
_mk_mach_lc_str_copy_native(mk_load_command_ref source_lc, union lc_str *source_str,
                            struct load_command *dest_lc, union lc_str *dest_str, size_t dest_cmd_size);

//! Copies the contents of the string referenced by the mach \c lc_str structure
//! for the given load command.
//!
//! @param  lc
//!         The load command containing the \c lc_str structure.  The full
//!         load command must be mapped into process accessible memory.
//! @param  lc_base_size
//!         \c sizeof(*lc);
//! @param  str
//!         A mach \c lc_str structure residing within the provided load
//!         command.
//! @param  output
//!         A buffer to receive the contents of the string.  May be \c NULL.
//! @param  output_len
//!         The size of the \a output buffer.
//! @param  include_terminator
//!         Forces the string copied to \a output to be \c NULL terminated
//!         regardless of whether the source string is terminated.
//! @return
//! The number of bytes required to receive the full contents of the string.
_mk_internal_extern size_t
_mk_mach_lc_str_copy(mk_load_command_ref source_lc, union lc_str *source_str,
                     char *output, size_t output_len, bool include_terminator);

#endif /* __mach_lcstr_h */
