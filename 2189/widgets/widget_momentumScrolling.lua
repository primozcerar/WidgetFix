-- Copyright © 2013 Corona Labs Inc. All Rights Reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of the company nor the names of its contributors
--      may be used to endorse or promote products derived from this software
--      without specific prior written permission.
--    * Redistributions in any form whatsoever must retain the following
--      acknowledgment visually in the program (e.g. the credits of the program): 
--      'This product includes software developed by Corona Labs Inc. (http://www.coronalabs.com).'
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL CORONA LABS INC. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


local M = {}

local thispath = select('1', ...):match(".+%.") or ""

-- Localize math functions
local mAbs = math.abs
local mFloor = math.floor

-- configuration variables
M.scrollStopThreshold = 250

-- direction variable that has a non-nil value only as long as the scrollview is scrolled
M._direction = nil

local isGraphicsV1 = ( 1 == display.getDefault( "graphicsCompatibility" ) )

-- Function to set the view's limits
local function setLimits( self, view )
	-- Set the bottom limit
	local bottomLimit = view._topPadding
	if isGraphicsV1 then
		bottomLimit = bottomLimit - view._height * 0.5
	end
	view.bottomLimit = bottomLimit
	
	-- TODO: use local functions for the limits instead of ifs
	
	-- Set the upper limit
	if view._scrollHeight then
		local upperLimit = ( -view._scrollHeight + view._height ) - view._bottomPadding
		
		-- the lower limit calculation is not necessary. We shift the view up with half its height, so the only thing we need to calculate
		-- is the upper limit.
		
		--if isGraphicsV1 then
		--	upperLimit = upperLimit - view._height * 0.5
		--end
		view.upperLimit = upperLimit
	end
	
	-- Set the right limit
	local rightLimit = view._leftPadding
	if isGraphicsV1 then
		rightLimit = rightLimit - view._width * 0.5
	end
	view.rightLimit = rightLimit

	-- Set the left limit
	if view._scrollWidth then
		local leftLimit = ( - view._scrollWidth + view._width ) - view._rightPadding
		if isGraphicsV1 then
			leftLimit = leftLimit - view._width * 0.5
		end
		view.leftLimit = leftLimit
	end
end

M.setLimits = setLimits

-- Function to handle vertical "snap back" on the view
local function handleSnapBackVertical( self, view, snapBack )
	
	-- Set the limits now
	setLimits( M, view )
	
	local limitHit = "none"
	local bounceTime = 400
	if not view.isBounceEnabled then
	    bounceTime = 0
	end
	
	-- Snap back vertically
	if not view._isVerticalScrollingDisabled then
		-- Put the view back to the top if it isn't already there ( and should be )
		if view.y > view.bottomLimit then
			-- Set the hit limit
			limitHit = "bottom"
			
			-- Transition the view back to it's maximum position
			if "boolean" == type( snapBack ) then
				if snapBack == true then
					-- Ensure the scrollBar is at the bottom of the view
					if view._scrollBar then
						view._scrollBar:setPositionTo( "top" )
					end
					
					-- Put the view back to the top
					view._snapping = true
					view._tween = transition.to( view, { time = bounceTime, y = view.bottomLimit, transition = easing.outQuad, onComplete = function() view._snapping = false; end } )						
				end
			end
			
		-- Put the view back to the bottom if it isn't already there ( and should be )
		elseif view.y < view.upperLimit then		
			-- Set the hit limit
			limitHit = "top"
			
			-- Transition the view back to it's maximum position
			if "boolean" == type( snapBack ) then
				if snapBack == true then
					-- Ensure the scrollBar is at the bottom of the view
					if view._scrollBar then
						view._scrollBar:setPositionTo( "bottom" )			
					end
					
					-- Put the view back to the bottom
					view._snapping = true
					view._tween = transition.to( view, { time = bounceTime, y = view.upperLimit, transition = easing.outQuad, onComplete = function() view._snapping = false; end } )
				end
			end
		end
	end
	
	return limitHit
end
	
-- Function to handle horizontal "snap back" on the view
local function handleSnapBackHorizontal( self, view, snapBack )

	-- Set the limits now
	setLimits( M, view )

	local limitHit = "none"
	local bounceTime = 400
	if not view.isBounceEnabled then
	    bounceTime = 0
	end
	
	-- Snap back horizontally
	if not view._isHorizontalScrollingDisabled then
		-- Put the view back to the left if it isn't already there ( and should be )
		if view.x < view.leftLimit then
			-- Set the hit limit
			limitHit = "left"
			
			-- Transition the view back to it's maximum position
			if "boolean" == type( snapBack ) then
				if snapBack == true then
					view._snapping = true
					view._tween = transition.to( view, { time = bounceTime, x = view.leftLimit, transition = easing.outQuad, onComplete = function() view._snapping = false; end } )
					
				end
			end
		
		-- Put the view back to the right if it isn't already there ( and should be )
		elseif view.x > view.rightLimit then
			-- Set the hit limit
			limitHit = "right"
			
			-- Transition the view back to it's maximum position
			if "boolean" == type( snapBack ) then
				if snapBack == true then
					view._snapping = true
					view._tween = transition.to( view, { time = bounceTime, x = view.rightLimit, transition = easing.outQuad, onComplete = function() view._snapping = false; end } )
				end
			end
		end
	end
	
	return limitHit
end

-- Function to clamp velocity to the maximum value
local function clampVelocity( view )
	-- Throttle the velocity if it goes over the max range
	if view._velocity < -view._maxVelocity then
		view._velocity = -view._maxVelocity
	elseif view._velocity > view._maxVelocity then
		view._velocity = view._maxVelocity
	end
end


-- Handle momentum scrolling touch
function M._touch( view, event )
	local phase = event.phase
	local time = event.time

	if "began" == phase then	
		-- Reset values	
		view._startXPos = event.x
		view._startYPos = event.y
		view._prevXPos = event.x
		view._prevYPos = event.y
		view._prevX = 0
		view._prevY = 0
		view._delta = 0
		view._velocity = 0
		view._prevTime = 0
		view._moveDirection = nil
		view._trackVelocity = true
		view._updateRuntime = false
		
		-- Set the limits now
		setLimits( M, view )
		
		-- Cancel any active tween on the view
		if view._tween then
			--if not view._snapping then  --cancel in any case, new tween will be created if not moved inside the bounds
				transition.cancel( view._tween )
				view._tween = nil
			--else
			--	transition.pause( view._tween )
			--end
		end				
		
		-- Set focus
		display.getCurrentStage():setFocus( event.target, event.id )
		view._isFocus = true
	
	elseif view._isFocus then
		if "moved" == phase then
			-- Set the move direction		
			if not view._moveDirection then
                            local dx = mAbs( event.x - event.xStart )
                            local dy = mAbs( event.y - event.yStart )
                            local moveThresh = 12

                            if dx > moveThresh or dy > moveThresh then
                                                -- If there is a scrollBar, show it
                                                if view._scrollBar then
                                                        -- Show the scrollBar, only if we need to (if the content height is higher than the view's height)
                                                        -- TODO: when the diagonal scrolling comes to place, we have to treat the horizontal case as well here.
                                                        if view._scrollBar._viewHeight < view._scrollBar._viewContentHeight then
                                                                view._scrollBar:show()
                                                        end
                                                end

                                if dx > dy then
                                                        -- If horizontal scrolling is enabled
                                                        if not view._isHorizontalScrollingDisabled then
                                                                -- The move was horizontal
                                        view._moveDirection = "horizontal"

                                                                -- Handle vertical snap back
                                                                handleSnapBackVertical( M, view, true )						
                                                        end
                                else
                                                        -- If vertical scrolling is enabled
                                                        if not view._isVerticalScrollingDisabled then
                                                                -- The move was vertical
                                            view._moveDirection = "vertical"
                                                                -- Handle horizontal snap back
                                                                handleSnapBackHorizontal( M, view, true )						
                                        end
				end
                            end
                        end
			
                        -- Horizontal movement
                        if "horizontal" == view._moveDirection then
                                -- If horizontal scrolling is enabled
                                if not view._isHorizontalScrollingDisabled then					
                                        view._delta = event.x - view._prevXPos
                                        view._prevXPos = event.x

                                        -- If the view is more than the limits
                                        if view.x < view.leftLimit or view.x > view.rightLimit then
                                                view.x = view.x + ( view._delta * 0.5 )
                                        else
                                                view.x = view.x + view._delta
                                                if view._listener and view._widgetType == "scrollView" then

                                                        local actualDirection

                                                        if view._delta < 0 then

                                                                actualDirection = "left"

                                                        elseif view._delta > 0 then

                                                                actualDirection = "right"

                                                        elseif view._delta == 0 then

                                                                if view._prevDeltaX and view._prevDeltaX < 0 then

                                                                        actualDirection = "left"

                                                                elseif view._prevDeltaX and view._prevDeltaX > 0 then

                                                                        actualDirection = "right"

                                                                end

                                                        end
                                                        -- if the scrollview is moving, assign the actual direction to the M._direction variable
                                                        M._direction = actualDirection

                                                end

                                        end

                                        view._prevDeltaX = view._delta

                                        local limit

                                        if view.isBounceEnabled == true then 
                                            -- if bounce is enabled and the view is used in picker, we snap back to prevent infinite scrolling
                                            if view._isUsedInPickerWheel == true then
                                                limit = handleSnapBackHorizontal( M, view, true )
                                            else
                                            -- if not used in picker, we don't need snap back so we don't lose elastic behaviour on the tableview
                                                limit = handleSnapBackHorizontal( M, view, false )
                                            end
                                        else
                                            limit = handleSnapBackHorizontal( M, view, true )
                                        end

                                end

                        -- Vertical movement
                        elseif view._moveDirection then
                                -- If vertical scrolling is enabled
                                if not view._isVerticalScrollingDisabled then
                                        view._delta = event.y - view._prevYPos
                                        view._prevYPos = event.y

                                        -- If the view is more than the limits
                                        if view.y < view.upperLimit or view.y > view.bottomLimit then
                                                view.y = view.y + ( view._delta * 0.5 )
                                                -- shrink the scrollbar if the view is out of bounds
                                                if view._scrollBar then
                                                        --view._scrollBar.yScale = 0.1 * - ( view.y - M.bottomLimit )
                                                end
                                        else
                                                view.y = view.y + view._delta 

                                                if view._listener and view._widgetType == "scrollView" then

                                                        local actualDirection

                                                        if view._delta < 0 then

                                                                actualDirection = "up"

                                                        elseif view._delta > 0 then

                                                                actualDirection = "down"

                                                        elseif view._delta == 0 then

                                                                if view._prevDeltaY and view._prevDeltaY < 0 then

                                                                        actualDirection = "up"

                                                                elseif view._prevDeltaY and view._prevDeltaY > 0 then

                                                                        actualDirection = "down"

                                                                end

                                                        end
                                                        -- if the scrollview is moving, assign the actual direction to the M._direction variable
                                                        M._direction = actualDirection

                                                end

                                        end

                                        view._prevDeltaY = view._delta

                                        -- Handle limits
                                        -- if bounce is true, then the snapback parameter has to be true, otherwise false
                                        local limit

                                        if view.isBounceEnabled == true then 
                                            -- if bounce is enabled and the view is used in picker, we snap back to prevent infinite scrolling
                                            if view._isUsedInPickerWheel == true then
                                                limit = handleSnapBackVertical( M, view, true )
                                            else
                                            -- if not used in picker, we don't need snap back so we don't lose elastic behaviour on the tableview
                                                limit = handleSnapBackVertical( M, view, false )
                                            end
                                        else
                                            limit = handleSnapBackVertical( M, view, true )
                                        end

                                        -- Move the scrollBar
                                        if limit ~= "top" and limit ~= "bottom" then
                                                if view._scrollBar then						
                                                        view._scrollBar:move()
                                                end
                                        end

                                        -- Set the time held
                                        --view._timeHeld = time				
                                end
                        end
                        
		elseif "ended" == phase or "cancelled" == phase then
		
			-- Reset values				
			view._lastTime = event.time
			view._trackVelocity = false			
			view._updateRuntime = true
			M._direction = nil
			
			-- we check if the view has a scrollStopThreshold value
			local stopThreshold = view.scrollStopThreshold or M.scrollStopThreshold
			
			if event.time - view._timeHeld > stopThreshold then
			    view._velocity = 0
			end
			view._timeHeld = 0
			
			-- when tapping fast and the view is at the limit, the velocity changes sign. This ALWAYS has to be treated.
			if view._delta > 0 and view._velocity < 0 then
			    view._velocity = - view._velocity
			end
			
			if view._delta < 0 and view._velocity > 0 then
			    view._velocity = - view._velocity
			end
	
			-- Remove focus								
			display.getCurrentStage():setFocus( nil )
			view._isFocus = nil
		
		-- if we have a snap transition that's paused, resume it
                -- we don't any more
		--if view._tween and true == view._snapping then
		--	transition.resume( view._tween )
		--end	
			
		end
	end
end


-- Handle runtime momentum scrolling events.
function M._runtime( view, event )

	-- If we are tracking runtime
	if view._updateRuntime then		
		local timePassed = event.time - view._lastTime
		view._lastTime = view._lastTime + timePassed
		
		-- Stop scrolling if velocity is near zero
		if mAbs( view._velocity ) < 0.01 then
			view._velocity = 0
			view._updateRuntime = false
			
			-- Hide the scrollBar
			if view._scrollBar and view.autoHideScrollBar then
				view._scrollBar:hide()
			end
		end
		
		-- Set the velocity
		view._velocity = view._velocity * view._friction
		
		-- Clamp the velocity if it goes over the max range
		clampVelocity( view )
	
		-- Horizontal movement
		if "horizontal" == view._moveDirection then
			-- If horizontal scrolling is enabled
			if not view._isHorizontalScrollingDisabled then
				-- Reset limit values
				view._hasHitLeftLimit = false
				view._hasHitRightLimit = false
				
				-- Move the view
				view.x = view.x + view._velocity * timePassed
			
				-- Handle limits
				local limit
				if "horizontal" == view._moveDirection then
                    limit = handleSnapBackHorizontal( M, view, true )
                else
                    limit = handleSnapBackHorizontal( M, view, false )
                end
			
				-- Left
				if "left" == limit then					
					-- Stop updating the runtime now
                                        view._velocity = 0
                                        view._updateRuntime = false
					
					-- If there is a listener specified, dispatch the event
					if view._listener then
						-- We have hit the left limit
						view._hasHitLeftLimit = true
						
						local newEvent = 
						{
							direction = "left",
							limitReached = true,
							target = view,
						}
						
						view._listener( newEvent )
					end
			
				-- Right
				elseif "right" == limit then					
					-- Stop updating the runtime now
                                        view._velocity = 0
                                        view._updateRuntime = false
					
					-- If there is a listener specified, dispatch the event
					if view._listener then
						-- We have hit the right limit
						view._hasHitRightLimit = true
						
						local newEvent = 
						{
							direction = "right",
							limitReached = true,
							target = view,
						}
						
						view._listener( newEvent )
					end
				end
			end	
			
		-- Vertical movement		
		else
			-- If vertical scrolling is enabled
			if not view._isVerticalScrollingDisabled then
				-- Reset limit values
				view._hasHitBottomLimit = false
				view._hasHitTopLimit = false
				
				-- Move the view
				view.y = view.y + view._velocity * timePassed
				
				-- Move the scrollBar
				if view._scrollBar then						
					view._scrollBar:move()
				end
	
				-- Handle limits
				-- if we have motion, then we check for snapback. otherwise, we don't.
				local limit
				
				if "vertical" == view._moveDirection then
                    limit = handleSnapBackVertical( M, view, true )
                else
                    limit = handleSnapBackVertical( M, view, false )
                end
	
				-- Top
				if "top" == limit then					
					-- Hide the scrollBar
					if view._scrollBar and view.autoHideScrollBar then
						view._scrollBar:hide()
					end
					
					-- We have hit the top limit
					view._hasHitTopLimit = true
										
					-- Stop updating the runtime now
                                        view._velocity = 0
					view._updateRuntime = false
										
					-- If there is a listener specified, dispatch the event
					if view._listener then
						local newEvent = 
						{
							direction = "up",
							limitReached = true,
							phase = event.phase,
							target = view,
						}
						
						view._listener( newEvent )
					end
							
				-- Bottom
				elseif "bottom" == limit then				
					-- Hide the scrollBar
					if view._scrollBar and view.autoHideScrollBar then
						view._scrollBar:hide()
					end
										
					-- We have hit the bottom limit
					view._hasHitBottomLimit = true
					
					-- Stop updating the runtime now
                                        view._velocity = 0
					view._updateRuntime = false
					
					-- If there is a listener specified, dispatch the event
					if view._listener then
						local newEvent = 
						{
							direction = "down",
							limitReached = true,
							target = view,
						}
						
						view._listener( newEvent )
					end
				end
			end
		end
	end
	
	-- If we are tracking velocity
	if view._trackVelocity then	
		-- Calculate the time passed
		local newTimePassed = event.time - view._prevTime
		view._prevTime = view._prevTime + newTimePassed

		-- Horizontal movement
		if "horizontal" == view._moveDirection then
			-- If horizontal scrolling is enabled
			if not view._isHorizontalScrollingDisabled then
				if view._prevX then
					local possibleVelocity = ( view.x - view._prevX ) / newTimePassed

	                if possibleVelocity ~= 0 then
	                    view._velocity = possibleVelocity
	
						-- Clamp the velocity if it goes over the max range
						clampVelocity( view )
	                end
				end
		
				view._prevX = view.x
			end
		
		-- Vertical movement
		elseif "vertical" == view._moveDirection then
			-- If vertical scrolling is enabled
			if not view._isVerticalScrollingDisabled then
				if view._prevY then
					local possibleVelocity = ( view.y - view._prevY ) / newTimePassed
                    
					if possibleVelocity ~= 0 then
                        view._velocity = possibleVelocity
						-- Clamp the velocity if it goes over the max range
						clampVelocity( view )
                    end
				end
		
				view._prevY = view.y
			end
		end
	end
end


-- Function to create a scrollBar
function M.createScrollBar( view, options )
	-- Require needed widget files
	local _widget = require( thispath.."widget" )
	
	local opt = {}
	local customOptions = options or {}
	
	-- Setup the scrollBar's width/height
	local parentGroup = view.parent.parent
	local scrollBarWidth = options.width or 5
	local viewHeight = view._height -- The height of the windows visible area
	local viewContentHeight = view._scrollHeight -- The height of the total content height
	local minimumScrollBarHeight = 24 -- The minimum height the scrollbar can be

	-- Set the scrollbar Height
	local scrollBarHeight = ( viewHeight * 100 ) / viewContentHeight
	
	-- If the calculated scrollBar height is below the minimum height, set it to it
	if scrollBarHeight < minimumScrollBarHeight then
		scrollBarHeight = minimumScrollBarHeight
	end
	
	-- Grab the theme options for the scrollBar
	local themeOptions = _widget.theme.scrollBar
	
	-- Get the theme sheet file and data
	opt.sheet = options.sheet
	opt.themeSheetFile = themeOptions.sheet
	opt.themeData = themeOptions.data
	opt.width = options.frameWidth or options.width or themeOptions.width
	opt.height = options.frameHeight or options.height or themeOptions.height
	
	-- Grab the frames
	opt.topFrame = options.topFrame or _widget._getFrameIndex( themeOptions, themeOptions.topFrame )
	opt.middleFrame = options.middleFrame or _widget._getFrameIndex( themeOptions, themeOptions.middleFrame )
	opt.bottomFrame = options.bottomFrame or _widget._getFrameIndex( themeOptions, themeOptions.bottomFrame )
	
	-- Create the scrollBar imageSheet
	local imageSheet
	
	if opt.sheet then
		imageSheet = opt.sheet
	else
		local themeData = require( opt.themeData )
	 	imageSheet = graphics.newImageSheet( opt.themeSheetFile, themeData:getSheet() )
	end
	
	-- The scrollBar is a display group
	M.scrollBar = display.newGroup()
	
	-- Create the scrollBar frames ( 3 slice )
	M.topFrame = display.newImageRect( M.scrollBar, imageSheet, opt.topFrame, opt.width, opt.height )
	if not isGraphicsV1 then
		M.topFrame.anchorX = 0.5; M.topFrame.anchorY = 0.5
	end
	
	M.middleFrame = display.newImageRect( M.scrollBar, imageSheet, opt.middleFrame, opt.width, opt.height )
	if not isGraphicsV1 then
		M.middleFrame.anchorX = 0.5; M.middleFrame.anchorY = 0.5
	end
	
	M.bottomFrame = display.newImageRect( M.scrollBar, imageSheet, opt.bottomFrame, opt.width, opt.height )
	if not isGraphicsV1 then
		M.bottomFrame.anchorX = 0.5; M.bottomFrame.anchorY = 0.5
	end
	
	-- Set the middle frame's width
	M.middleFrame.height = scrollBarHeight - ( M.topFrame.contentHeight + M.bottomFrame.contentHeight )
	
	-- Positioning
	M.middleFrame.y = M.topFrame.y + M.topFrame.contentHeight * 0.5 + M.middleFrame.contentHeight * 0.5
	M.bottomFrame.y = M.middleFrame.y + M.middleFrame.contentHeight * 0.5 + M.bottomFrame.contentHeight * 0.5
	
	-- Setup the scrollBar's properties
	M.scrollBar._viewHeight = viewHeight
	M.scrollBar._viewContentHeight = viewContentHeight
	M.scrollBar.alpha = 0 -- The scrollBar is invisible initally
	M.scrollBar._tween = nil
	
	-- function to recalculate the scrollbar params, based on content height change
	function M.scrollBar:repositionY()
	
	    self._viewHeight = view._height
	    self._viewContentHeight = view._scrollHeight
	    -- Set the scrollbar Height
	    
	    local scrollBarHeight = ( self._viewHeight * 100 ) / self._viewContentHeight
	    
	    -- If the calculated scrollBar height is below the minimum height, set it to it
	    if scrollBarHeight < minimumScrollBarHeight then
		    scrollBarHeight = minimumScrollBarHeight
	    end
	
        M.middleFrame.height = scrollBarHeight - ( M.topFrame.contentHeight + M.bottomFrame.contentHeight ) 
    
    	-- Positioning of the middle and bottom frames according to the new scrollbar height
		M.middleFrame.y = M.topFrame.y + M.topFrame.contentHeight * 0.5 + M.middleFrame.contentHeight * 0.5
		M.bottomFrame.y = M.middleFrame.y + M.middleFrame.contentHeight * 0.5 + M.bottomFrame.contentHeight * 0.5
	end
	
	-- Function to move the scrollBar
	function M.scrollBar:move()
	
		local viewY = view.y
		if isGraphicsV1 then
			viewY = viewY + view.parent.contentHeight * 0.5
		end
	
		local moveFactor = ( viewY * 100 ) / ( self._viewContentHeight - self._viewHeight )		
		local moveQuantity = ( moveFactor * ( self._viewHeight - self.contentHeight ) ) / 100
				
		if viewY < 0 then
			-- Only move if not over the bottom limit
			if mAbs( view.y ) < ( self._viewContentHeight ) then
				self.y = view.parent.y - view._top - moveQuantity
			end
		end		
	end
	
	function M.scrollBar:setPositionTo( position )
		if "top" == position then
			self.y = view.parent.y - view._top
		elseif "bottom" == position then
			self.y = self._viewHeight - self.contentHeight
		end
	end
	
	-- Function to show the scrollBar
	function M.scrollBar:show()
		-- Cancel any previous transition
		if self._sbTween then
			transition.cancel( self._tween ) 
			self._sbTween = nil
		end
		
		-- Set the alpha of the bar back to 1
		self.alpha = 1
	end
	
	-- Function to hide the scrollBar
	function M.scrollBar:hide()
		-- If there already isn't a tween in progress
		if not self._sbTween then
			self._sbTween = transition.to( self, { time = 400, alpha = 0, transition = easing.outQuad } )
		end
	end
		
	-- Insert the scrollBar into the fixed group and position it
	view._fixedGroup:insert( M.scrollBar )
	
	view._fixedGroup.x = view._width * 0.5 - scrollBarWidth * 0.5
	--local viewFixedGroupY = view.parent.y - view._top - view._height * 0.5
	
	-- this has to be positioned at the yCoord - half the height, no matter what.
	local viewFixedGroupY = - view.parent.contentHeight * 0.5
	view._fixedGroup.y = viewFixedGroupY
	
	-- calculate the limits. Fixes placement errors for the scrollbar.
	setLimits( M, view )
	
	-- set the widget y coord according to the calculated limits
        if not view._didSetLimits then
            view.y = view.bottomLimit
            view._didSetLimits = true
        else
            M.scrollBar:repositionY()
        end
	
	if not view.autoHideScrollBar then
		M.scrollBar:show()
	end
	
	return M.scrollBar
end

return M
