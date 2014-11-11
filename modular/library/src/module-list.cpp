/* Copyright (C) 2003-2013 Runtime Revolution Ltd.
 
 This file is part of LiveCode.
 
 LiveCode is free software; you can redistribute it and/or modify it under
 the terms of the GNU General Public License v3 as published by the Free
 Software Foundation.
 
 LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 for more details.
 
 You should have received a copy of the GNU General Public License
 along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

#include <foundation.h>
#include <foundation-auto.h>
#include <foundation-chunk.h>

void MCListEvalHeadOf(MCProperListRef p_target, MCValueRef& r_output)
{
    r_output = MCValueRetain(MCProperListFetchHead(p_target));
}

void MCListEvalTailOf(MCProperListRef p_target, MCValueRef& r_output)
{
    r_output = MCValueRetain(MCProperListFetchTail(p_target));
}

void MCListExecPushSingleElementOnto(MCValueRef p_value, MCProperListRef& x_target)
{
    if (MCProperListPushElement(x_target, p_value))
        return;
    
//    ctxt . Throw();
}

void MCListExecPushMultipleElementsOnto(MCProperListRef p_value, MCProperListRef& x_target)
{
    if (MCProperListAppendList(x_target, p_value))
        return;
    
//    ctxt . Throw();
}

void MCListExecPopElementInto(MCProperListRef& x_source, MCValueRef& r_output)
{
    if (MCProperListPop(x_source, r_output))
        return;
    
//    ctxt . Throw();
}

void MCListExecInsertSingleElementIntoListAt(MCValueRef p_value, MCProperListRef& x_target, index_t p_index)
{
    if (MCProperListInsertElement(x_target, p_value, p_index))
        return;
    
    //    ctxt . Throw();
}

void MCListExecInsertMultipleElementsIntoListAt(MCProperListRef p_value, MCProperListRef& x_target, index_t p_index)
{
    if (MCProperListInsertList(x_target, p_value, p_index))
        return;
    
    //    ctxt . Throw();
}

void MCListEvalNumberOfElementsIn(MCProperListRef p_target, uindex_t& r_output)
{
    r_output = MCProperListGetLength(p_target);
}

void MCListEvalIsAmongTheElementsOf(MCValueRef p_needle, MCProperListRef p_target, bool& r_output)
{
    uindex_t t_dummy;
    r_output = MCProperListFirstIndexOfElement(p_target, p_needle, 0, t_dummy);
}

void MCListEvalContains(MCProperListRef p_target, MCProperListRef p_needle, bool& r_output)
{
    uindex_t t_dummy;
    r_output = MCProperListFirstIndexOfList(p_target, p_needle, 0, t_dummy);
}

void MCListFetchElementOf(index_t p_index, MCProperListRef p_target, MCValueRef& r_output)
{
    uindex_t t_start, t_count;
    MCChunkGetExtentsOfElementChunkByExpression(p_target, p_index, t_start, t_count);
    r_output = MCValueRetain(MCProperListFetchElementAtIndex(p_target, t_start));
}

void MCListStoreElementOf(MCValueRef p_value, index_t p_index, MCProperListRef& x_target)
{
    uindex_t t_start, t_count;
    MCChunkGetExtentsOfElementChunkByExpression(x_target, p_index, t_start, t_count);
    MCProperListInsertElement(x_target, p_value, t_start);
}

void MCListFetchElementRangeOf(index_t p_start, index_t p_finish, MCProperListRef p_target, MCProperListRef& r_output)
{
    uindex_t t_start, t_count;
    MCChunkGetExtentsOfElementChunkByRange(p_target, p_start, p_finish, t_start, t_count);
    MCProperListCopySublist(p_target, MCRangeMake(p_start, p_finish - p_start + 1), r_output);
}

void MCListStoreElementRangeOf(MCValueRef p_value, index_t p_start, index_t p_finish, MCProperListRef& x_target)
{
    uindex_t t_start, t_count;
    MCChunkGetExtentsOfElementChunkByRange(x_target, p_start, p_finish, t_start, t_count);
    // PUT INTO AMBIGUITY
}

void MCListStoreAfterElementOf(MCValueRef p_value, index_t p_index, MCProperListRef& x_target)
{
    uindex_t t_start, t_count;
    t_start += t_count;
    MCChunkGetExtentsOfElementChunkByExpression(x_target, p_index, t_start, t_count);
    MCProperListInsertElement(x_target, p_value, t_start);
}

void MCListStoreBeforeElementOf(MCValueRef p_value, index_t p_index, MCProperListRef& x_target)
{
    uindex_t t_start, t_count;
    MCChunkGetExtentsOfElementChunkByExpression(x_target, p_index, t_start, t_count);
    MCProperListInsertElement(x_target, p_value, t_start);
}

////////////////////////////////////////////////////////////////////////////////////////////////////

void MCListSpliceIntoElementRangeOf(MCProperListRef p_list, index_t p_start, index_t p_finish, MCProperListRef& x_target)
{
    uindex_t t_start, t_count;
    MCChunkGetExtentsOfElementChunkByRange(x_target, p_start, p_finish, t_start, t_count);
    
    MCProperListRemoveElements(x_target, t_start, t_start + t_count);
    MCProperListInsertList(x_target, p_list, t_start);
}

void MCListSpliceIntoElementOf(MCProperListRef p_list, index_t p_index, MCProperListRef& x_target)
{
    MCListSpliceIntoElementRangeOf(p_list, p_index, p_index, x_target);
}

void MCListSpliceBeforeElementOf(MCProperListRef p_list, index_t p_index, MCProperListRef& x_target)
{
    uindex_t t_start, t_count;
    MCChunkGetExtentsOfElementChunkByExpression(x_target, p_index, t_start, t_count);
    
    MCProperListInsertList(x_target, p_list, t_start);
}

void MCListSpliceAfterElementOf(MCProperListRef p_list, index_t p_index, MCProperListRef& x_target)
{
    uindex_t t_start, t_count;
    MCChunkGetExtentsOfElementChunkByExpression(x_target, p_index, t_start, t_count);
    
    t_start += t_count;
    
    MCProperListInsertList(x_target, p_list, t_start);
}

////////////////////////////////////////////////////////////////////////////////////////////////////

extern void log(const char *module, const char *test, bool result);
#define log_result(test, result) log("LIST MODULE", test, result)
void MCListRunTests()
{
/*
    MCListEvalHeadOf(MCProperListRef p_target, MCValueRef& r_output)
    MCListEvalTailOf(MCProperListRef p_target, MCValueRef& r_output)
    MCListExecPushSingleElementOnto(MCValueRef p_value, MCProperListRef& x_target)
    MCListExecPushMultipleElementsOnto(MCProperListRef p_value, MCProperListRef& x_target)
    MCListExecPopElementInto(MCProperListRef& x_source, MCValueRef& r_output)
    MCListExecInsertSingleElementIntoListAt(MCValueRef p_value, MCProperListRef& x_target, index_t p_index)
    MCListExecInsertMultipleElementsIntoListAt(MCProperListRef p_value, MCProperListRef& x_target, index_t p_index)
    MCListStoreElementOf(MCValueRef p_value, index_t p_index, MCProperListRef& x_target)
    MCListStoreElementRangeOf(MCValueRef p_value, index_t p_start, index_t p_finish, MCProperListRef& x_target)
*/
    MCAutoProperListRef t_list;
    MCProperListCreateMutable(&t_list);
    
    MCProperListPushElement(*t_list, kMCEmptyArray);
    MCProperListPushElement(*t_list, kMCEmptyString);
    MCProperListPushElement(*t_list, kMCEmptyName);
    MCProperListPushElement(*t_list, kMCEmptyProperList);
    MCProperListPushElement(*t_list, kMCEmptySet);
    
    /*MCListEvalNumberOfElementsIn(MCProperListRef p_target, uindex_t& r_output)*/
    
    uindex_t t_num;
    MCListEvalNumberOfElementsIn(*t_list, t_num);
    log_result("number of elements in", t_num == 5);
    
    MCValueRef t_value;
    t_value = nil;
    
    /*MCListFetchElementOf(index_t p_index, MCProperListRef p_target, MCValueRef& r_output)*/
    MCListFetchElementOf(5, *t_list, t_value);

    MCAssert(t_value != nil);
    log_result("fetch element x of", MCValueIsEqualTo(t_value, kMCEmptySet));
    
    /*MCListFetchElementRangeOf(index_t p_start, index_t p_finish, MCProperListRef p_target, MCProperListRef& r_output)*/
    MCAutoProperListRef t_sublist;
    MCListFetchElementRangeOf(2, 3, *t_list, &t_sublist);
    
    MCAssert(*t_sublist != nil);
    log_result("fetch element range of", MCProperListGetLength(*t_sublist) == 2);
    
    /*MCListEvalContains(MCProperListRef p_target, MCProperListRef p_needle, bool& r_output)*/
    bool t_result;
    MCListEvalContains(*t_list, *t_sublist, t_result);
    log_result("contains", t_result);
    
    /*MCListEvalIsAmongTheElementsOf(MCValueRef p_needle, MCProperListRef p_target, bool& r_output)*/
    bool t_is_among;
    MCListEvalIsAmongTheElementsOf(kMCEmptyName, *t_list, t_is_among);

    log_result("is among elements of", t_is_among);    
}