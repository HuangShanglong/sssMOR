function [sysr, V, W, Bb, Ct, Cb, Bt] = RK(sys, s0_inp, s0_out, IP)
% Model Order Reduction by Rational Krylov (Krylov Subspace Method)
% ------------------------------------------------------------------
% [sysr, V, W] = RK(sys, s0_inp, s0_out, IP)
% Inputs:       * sys: an sss-object containing the LTI system
%               * s0_inp: Expansion points for Input Krylov Subspace
%               * s0_out: Expansion points for Output Krylov Subspace
%               * IP: Inner product (optional)
% Outputs:      * sysr: reduced system
%               * V, W: Projection matrices spanning Krylov subspaces
% ------------------------------------------------------------------
% Usage:  s0 may either be horizontal vectors containing the desired
% expansion points, e.g. [1 2 3] matches one moment about 1, 2 and 3,
% respectively. [1+1j 1-1j 5 5 5 5 inf inf] matches one moment about 1+1j,
% 1-1j, 4 moments about 5 and 2 Markov parameters.
%
% An alternative notation for s0 is a two-row matrix, containing the
% expansion points in the first row and their multiplicity in the second,
% e.g. [4 pi inf; 1 20 10] matches one moment about 4, 20 moments about pi
% and 10 Markov parameters.
% ------------------------------------------------------------------
% To perform one-sided RK, set s0_inp or s0_out to [], respectively.
% ------------------------------------------------------------------
% This file is part of the MORLAB_GUI, a Model Order Reduction and
% System Analysis Toolbox developed at the
% Institute of Automatic Control, Technische Universitaet Muenchen
% For updates and further information please visit www.rt.mw.tum.de
% ------------------------------------------------------------------
% Authors:      Heiko Panzer (heiko@mytum.de)
% Last Change:  23 Jan 2012
% ------------------------------------------------------------------

if ~exist('IP', 'var'), IP=@(x,y) (x'*sys.E*y); end

if  (~exist('s0_inp', 'var') || isempty(s0_inp)) && ...
    (~exist('s0_out', 'var') || isempty(s0_out))
    error('No expansion points assigned.');
end

if exist('s0_inp', 'var')
    s0_inp = s0_vect(s0_inp);
else
    s0_inp = [];
end
if exist('s0_out', 'var')
    s0_out = s0_vect(s0_out);
else
    s0_out = [];
end

if ~isempty(s0_inp) && ~isempty(s0_out)
    % check if number of input/output expansion points matches
    if length(s0_inp) ~= length(s0_inp)
        error('Inconsistent length of expansion point vectors.');
    end
end

if isempty(s0_out)
    % input Krylov subspace
    if sys.m>1
        % MIMO ***
        error('RK is not available for MIMO systems, yet.')
    end
    % SISO Arnoldi
    [V,AV,EV,Ct] = arnoldi(sys.E, sys.A, sys.B, s0_inp, IP);
    W = V;
    sysr = sss(V'*AV, V'*sys.B, sys.C*V, sys.D, V'*EV);
    Bb = sys.B - EV*(sysr.E\sysr.B);
    Cb = []; Bt = [];

%     svd(AV-EV/sysr.E*sysr.A)    
    
elseif isempty(s0_inp)
    % output Krylov subspace
    if sys.p>1
        % MIMO ***
        error('RK is not available for MIMO systems, yet.')
    end
    % SISO Arnoldi
    [W,AtW,EtW,Bt] = arnoldi(sys.E', sys.A', sys.C', s0_out, IP);
    V = W;
    sysr = sss(AtW'*W, W'*sys.B, sys.C*W, sys.D, EtW'*W);
    Bt = Bt';
    Cb = sys.C - sysr.C/sysr.E*EtW';
    Bb = []; Ct = [];
else
    [V,AV,EV,Ct] = arnoldi(sys.E, sys.A, sys.B, s0_inp, IP);
    [W,~,EtW,Bt] = arnoldi(sys.E', sys.A', sys.C', s0_out, IP);
%    [V,W]=lanczos(sys.E,sys.A,sys.B,sys.C,s0_inp,s0_out,IP);
    sysr = sss(W'*AV, W'*sys.B, sys.C*V, sys.D, W'*EV);
    Bt = Bt';
    Bb = sys.B - EV*(sysr.E\sysr.B);
    Cb = sys.C - sysr.C/sysr.E*EtW';
end

end

function s0=s0_vect(s0)
    % change two-row notation to vector notation
    if size(s0,1)==2
        temp=zeros(1,sum(s0(2,:)));
        for j=1:size(s0,2)
            k=sum(s0(2,1:(j-1))); k=(k+1):(k+s0(2,j));
            temp(k)=s0(1,j)*ones(1,s0(2,j));
        end
        s0=temp;
    end
    % sort expansion points
    s0 = cplxpair(s0);
    if size(s0,1)>size(s0,2)
        s0=transpose(s0);
    end
end


