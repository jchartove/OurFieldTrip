function [Zi, h] = ft_plot_topo(chanX, chanY, dat, varargin)

% FT_PLOT_TOPO interpolates and plots the 2-D spatial topography of the
% potential or field distribution over the head
%
% Use as
%   ft_plot_topo(x, y, val, ...)
%
% Optional arguments should come in key-value pairs and can include
%   'gridscale'     = scalar, number of points along both directions for interpolation (default = 67)
%   'datmask'       = vector of same dimensions as val
%   'mask'          = cell-array with line segments that forms the mask (see FT_PREPARE_LAYOUT)
%   'outline'       = cell-array with line segments that for the outline (see  FT_PREPARE_LAYOUT)
%   'isolines'      = vector with values for isocontour lines (default = [])
%   'interplim'    = string, 'electrodes' or 'mask' (default = 'electrodes')
%   'interpmethod'  = string, 'nearest', 'linear', 'natural', 'cubic' or 'v4' (default = 'v4')
%   'style'         = can be 'surf', 'iso', 'isofill', 'surfiso', 'imsat', 'imsatiso'
%   'clim'          = [min max], limits for color scaling
%   'shading'       = string, 'none', 'flat', 'interp' (default = 'flat')
%   'parent'        = handle which is set as the parent for all plots
%   'tag'           = string, the name this vector gets. All tags with the same name can be deleted in a figure, without deleting other parts of the figure.
%
% It is possible to plot the object in a local pseudo-axis (c.f. subplot), which is specfied as follows
%   'hpos'          = horizontal position of the lower left corner of the local axes
%   'vpos'          = vertical position of the lower left corner of the local axes
%   'width'         = width of the local axes
%   'height'        = height of the local axes
%   'hlim'          = horizontal scaling limits within the local axes
%   'vlim'          = vertical scaling limits within the local axes

% Copyrights (C) 2009-2013, Giovanni Piantoni, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% these are for speeding up the plotting on subsequent calls
persistent previous_argin

ws = warning('on', 'MATLAB:divideByZero');

% get the optional input arguments
hpos          = ft_getopt(varargin, 'hpos',         0);
vpos          = ft_getopt(varargin, 'vpos',         0);
width         = ft_getopt(varargin, 'width',        []);
height        = ft_getopt(varargin, 'height',       []);
gridscale     = ft_getopt(varargin, 'gridscale',    67); % 67 in original
shading       = ft_getopt(varargin, 'shading',      'flat');
interplim     = ft_getopt(varargin, 'interplim',    'electrodes');
interpmethod  = ft_getopt(varargin, 'interpmethod', 'v4');
style         = ft_getopt(varargin, 'style',        'surfiso'); % can be 'surf', 'iso', 'isofill', 'surfiso', 'imsat', 'imsatiso'
tag           = ft_getopt(varargin, 'tag',          '');
isolines      = ft_getopt(varargin, 'isolines');
datmask       = ft_getopt(varargin, 'datmask');
mask          = ft_getopt(varargin, 'mask');
outline       = ft_getopt(varargin, 'outline');
clim          = ft_getopt(varargin, 'clim', []);
parent        = ft_getopt(varargin, 'parent', []);

% check for nans in the data, they can be still left incase people want to mask non channels.
if any(isnan(dat))
  warning('the data passed to ft_plot_topo contains NaNs, these channels will be removed from the data to prevent interpolation errors, but will remain in the mask');
  flagNaN = true;
else
  flagNaN = false;
end
NaNind = isnan(dat);

% everything is added to the current figure
holdflag = ishold;
if ~holdflag
  hold on
end

% layout units can be arbitrary (e.g. pixels for .mat files)
% so we need to compute the right scaling factor
% create a matrix with all coordinates
% from positions, mask, and outline
allCoords = [chanX chanY];
if ~isempty(mask)
  for k = 1:numel(mask)
    allCoords = [allCoords; mask{k}];
  end
end
if ~isempty(outline)
  for k = 1:numel(outline)
    allCoords = [allCoords; outline{k}];
  end
end

naturalWidth = (max(allCoords(:, 1))-min(allCoords(:, 1)));
naturalHeight = (max(allCoords(:, 2))-min(allCoords(:, 2)));

if isempty(width) && isempty(height)
  xScaling = 1;
  yScaling = 1;
elseif isempty(width) && ~isempty(height)
  % height specified, auto-compute width while maintaining aspect ratio
  yScaling = height/naturalHeight;
  xScaling = yScaling;
elseif ~isempty(width) && isempty(height)
  % width specified, auto-compute height while maintaining aspect ratio
  xScaling = width/naturalWidth;
  yScaling = xScaling;
else
  % both width and height specified
  xScaling = width/naturalWidth;
  yScaling = height/naturalHeight;
end

% keep original channel positions
chanXorg = chanX;
chanYorg = chanY;
chanX = chanX(:) * xScaling + hpos;
chanY = chanY(:) * yScaling + vpos;

if strcmp(interplim, 'electrodes'),
  hlim = [min(chanX) max(chanX)];
  vlim = [min(chanY) max(chanY)];
elseif (strcmp(interplim, 'mask') || strcmp(interplim, 'mask_individual')) && ~isempty(mask),
  hlim = [inf -inf];
  vlim = [inf -inf];
  for i=1:length(mask)
    hlim = [min([hlim(1); mask{i}(:, 1)*xScaling+hpos]) max([hlim(2); mask{i}(:, 1)*xScaling+hpos])];
    vlim = [min([vlim(1); mask{i}(:, 2)*yScaling+vpos]) max([vlim(2); mask{i}(:, 2)*yScaling+vpos])];
  end
else
  hlim = [min(chanX) max(chanX)];
  vlim = [min(chanY) max(chanY)];
end

% check if all mask point are inside the limits otherwise redefine mask
newpoints = [];
if length(mask)==1
  % which channels are outside
  outside = false(length(chanX), 1);
  inside  = inside_contour([chanX chanY], mask{1});
  outside = ~inside;
  newpoints = [chanX(outside) chanY(outside)];
end

% try to speed up the preparation of the mask on subsequent calls
%current_argin = {chanX, chanY, gridscale, mask, datmask}; % old: to be plotted channel positions must be the same
current_argin = {chanXorg, chanYorg, gridscale, mask, datmask, interplim}; % new: unscaled channel positions must be the same over calls
if isequal(current_argin, previous_argin) || ~isempty(mask)
  % convert the mask into a binary image
  maskimage = zeros(gridscale);%false(gridscale);
  %hlim      = [min(chanX) max(chanX)];
  %vlim      = [min(chanY) max(chanY)];
  xi        = linspace(hlim(1), hlim(2), gridscale);   % x-axis for interpolation (row vector)
  yi        = linspace(vlim(1), vlim(2), gridscale);   % y-axis for interpolation (row vector)
  [Xi, Yi]   = meshgrid(xi', yi);
  if ~isempty(newpoints) && (hpos == 0 || vpos == 0)
    warning('Some points fall outside the outline, please consider using another layout')
    % FIXME: I am not sure about it, to be tested!
    %     tmp = [mask{1};newpoints];
    %     indx = convhull(tmp(:, 1), tmp(:, 2));
    %     mask{1} = tmp(indx, :);
    % NOTE: if you set hpos and/or vpos, newpoints is not empty, but nothing
    % needs to be fixed (this fixme screws up things, then)
  end
  for i=1:length(mask)
    mask{i}(:, 1) = mask{i}(:, 1)*xScaling+hpos;
    mask{i}(:, 2) = mask{i}(:, 2)*yScaling+vpos;
    mask{i}(end+1, :) = mask{i}(1, :);                   % force them to be closed
    maskimage(inside_contour([Xi(:) Yi(:)], mask{i})) = i;%true;
  end
  
else
  maskimage = [];
end

% adjust maskimage to also mask channels as specified in maskdat
if ~isempty(datmask)
  xi           = linspace(hlim(1), hlim(2), gridscale);   % x-axis for interpolation (row vector)
  yi           = linspace(vlim(1), vlim(2), gridscale);   % y-axis for interpolation (row vector)
  maskimagetmp = griddata(chanX', chanY, double(datmask), xi', yi, 'nearest'); % interpolate the mask data
  if isempty(maskimage)
    maskimage = maskimagetmp;
  else
    %maskimage = (maskimage + maskimagetmp) > 1.01;
    %maskimage = (maskimage .* maskimagetmp); % commented out 12/28/19
    %-john
  end
end

% take out NaN channels if interpmethod does not work with NaNs
if flagNaN && strcmp(interpmethod, default_interpmethod)
  dat(NaNind) = [];
  chanX(NaNind) = [];
  chanY(NaNind) = [];
end

% convert chanX, chanY and dat to double
dat = double(dat);
chanX = double(chanX);
chanY = double(chanY);

%interpolate data
xi         = linspace(hlim(1), hlim(2), gridscale);       % x-axis for interpolation (row vector)
yi         = linspace(vlim(1), vlim(2), gridscale);       % y-axis for interpolation (row vector)

if ~ft_platform_supports('griddata-vector-input')
  % in GNU Octave, griddata does not support vector
  % positions; make a grid to get the locations in vector form
  [xi,yi]=meshgrid(xi,yi);
  xi=xi';
end

if ~isempty(maskimage) && strcmp(interplim, 'mask_individual')
  % do the interpolation for each set of electrodes within a mask, useful
  % for ECoG data with multiple grids, to avoid cross talk
  Zi = zeros(size(maskimage));
  for i=1:max(maskimage(:))
    chansel = inside_contour([chanX chanY], mask{i});
    [Xi, Yi, tmpZi]  = griddata(chanX(chansel)', chanY(chansel), dat(chansel), xi', yi, interpmethod);
    Zi(maskimage==i) = tmpZi(maskimage==i);
  end
else
  [Xi, Yi, Zi] = griddata(chanX', chanY, dat, xi', yi, interpmethod); % interpolate the topographic data
end

if ~isempty(maskimage)
  % make boolean  
  %maskimage      = maskimage~=0;
  % apply mask to the data to hide parts of the interpolated data (outside the circle) and channels that were specified to be masked
  % this combines the input options mask and maskdat
  Zi(~maskimage) = NaN;
end

% The topography should be plotted prior to the isolines to ensure that it is exported correctly, see http://bugzilla.fcdonders.nl/show_bug.cgi?id=2496
if strcmp(style, 'surf') || strcmp(style, 'surfiso')
  
  deltax = xi(2)-xi(1); % length of grid entry
  deltay = yi(2)-yi(1); % length of grid entry
  h = surf(Xi-deltax/2, Yi-deltay/2, zeros(size(Zi)), Zi, 'EdgeColor', 'none', 'FaceColor', shading);  
  if ~any(diff(maskimage(maskimage ~= 0)) ~= 0)
      maskimagetp = find(maskimage(maskimage ~= 0));
      maskimage(maskimagetp(1)) = 1;
  end
 h.AlphaData = maskimage;
 h.FaceColor = 'texturemap';
 h.FaceAlpha = 'texturemap';
  set(h, 'tag', tag);
  if ~isempty(parent)
    set(h, 'Parent', parent);
  end
  
  % this is an alternative to using NaN values to hide parts of the interpolated data (outside the circle), but fails in eps files
  % the NaN solution is more robust and works for all renderers and file formats
  %   if ~isempty(maskimage)
  %     set(h, 'facealpha', 'flat');
  %     set(h, 'alphadatamapping', 'scaled');
  %     set(h, 'alphadata', maskimage);
  %   end
  
elseif strcmp(style, 'imsat') || strcmp(style, 'imsatiso')
  % Plot the surface in an alternate style (using imagesc and saturation masking) so that it can be nicely saved to a vectorized format
 
  % set mask and cdat, and check for clim
  if isempty(clim)
    error('clim is required for style = ''imsat'' or style = ''imsatiso''')
  end
  satmask = maskimage;
  cdat = Zi;
  % below code is shared with ft_plot_matrix
  
  
  % This approach changes the color of pixels to white, regardless of colormap, without using opengl
  % It does by converting by:
  % 1) convert the to-be-plotted data to their respective rgb color values (determined by colormap)
  % 2) convert these rgb color values to hsv values, hue-saturation-value
  % 3) for to-be-masked-pixels, set saturation to 0 and value to 1 (hue is irrelevant when they are)
  % 4) convert the hsv values back to rgb values
  % 5) plot these values
  
  % enforce mask properties (satmask is 0 when a pixel needs to be masked, 1 if otherwise)
  satmask = round(double(satmask));   % enforce binary white-masking, the hsv approach cannot be used for 'white-shading'
  satmask(isnan(cdat)) = false;       % make sure NaNs are plotted as white pixels, even when using non-integer mask values
  
  % do 1, by converting the data-values to zero-based indices of the colormap
  ncolors = size(get(gcf, 'colormap'), 1); % determines range of index, if a figure has been created by the caller function, gcf changes nothing, if not, a figure is created (which the below would do otherwise)
  indcdat = (cdat + -clim(1)) * (ncolors / (-clim(1) + clim(2))); % transform cdat-values to have a 0-(ncolors-1) range (range depends on colormap used, and thus also on clim)
  rgbcdat = ind2rgb(uint8(floor(indcdat)), colormap);
  % do 2
  hsvcdat = rgb2hsv(rgbcdat);
  % do 3
  hsvs = hsvcdat(:,:,2);
  hsvs(~satmask) = 0;
  hsvv = hsvcdat(:,:,3);
  hsvv(~satmask) = 1;
  hsvcdat(:,:,2) = hsvs;
  hsvcdat(:,:,3) = hsvv;
  % do 4
  rgbcdat = hsv2rgb(hsvcdat);
  % do 5
  h = imagesc(xi, yi, rgbcdat, clim);
  set(h, 'tag', tag);

end

% Plot the outline of the head, ears and nose
for i=1:length(outline)
  xval = outline{i}(:, 1) * xScaling  + hpos;
  yval = outline{i}(:, 2) * yScaling + vpos;
  ft_plot_vector(xval, yval, 'Color', 'k', 'LineWidth', 2, 'tag', tag, 'parent', parent);
end

% Create isolines
if strcmp(style, 'iso') || strcmp(style, 'surfiso') ||  strcmp(style, 'imsatiso')
  if ~isempty(isolines)
    [cont, h] = contour(Xi, Yi, Zi, isolines, 'k');
    set(h, 'tag', tag);
    if ~isempty(parent)
      set(h, 'Parent', parent);
    end
  end
end

% Plot filled contours
if strcmp(style, 'isofill') && ~isempty(isolines)
  [cont, h] = contourf(Xi, Yi, Zi, isolines, 'k');
  h.LineColor = 'none';
  h.UserData = h.ZData;
  maskimage(~logical(round(maskimage))) = nan;
  h.ZData = h.ZData.*maskimage;
  set(h, 'tag', tag);
  if ~isempty(parent)
    set(h, 'Parent', parent);
  end
end

% apply clim if it was given
if ~isempty(clim)
  caxis(clim)
end

% remember the current input arguments, so that they can be
% reused on a subsequent call in case the same input argument is given
previous_argin     = current_argin;

if ~holdflag
  hold off
end

warning(ws); % revert to original state
