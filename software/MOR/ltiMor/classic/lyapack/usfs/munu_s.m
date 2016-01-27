function Y = munu_s(tr,X,i)
%
%  Solves shifted linear systems with the real matrix A or its 
%  transposed A':
%
%  for tr = 'N':
%
%    Y = inv(A+p(i)*I)*X;
%
%  for tr = 'T':
%
%    Y = inv(A.'+p(i)*I)*X.
%
%  A+p(i)*I is given implicitely in a factored form. The factores are
%  provided as global data. These data must be generated by calling
%  'munu_m_i' AND 'munu_s_i' before calling this routine!
%  
%  Calling sequence:
%
%    Y = munu_s(tr,X,i)
%
%  Input:
%
%    tr        (= 'N' or 'T') determines whether shifted systems with 
%              A or A' should be solved;
%    X         a matrix of proper size;
%    i         the index of the shift parameter.
%
%  Output:
%
%    Y         the resulting solution matrix.
%  
%
%   LYAPACK 1.6 (Jens Saak, October 2007)

if nargin~=3
  error('Wrong number of input arguments.');
end

global LP_ML LP_MU LP_LC LP_UC LP_aC LP_oC LP_SC

if isempty(LP_ML) || isempty(LP_MU)
  error('This routine needs global data which must be generated by calling ''munu_m_i'' first.');
end 

is_init1 = ~isempty(LP_LC{i});
is_init2 = ~isempty(LP_UC{i});
is_init3 = ~isempty(LP_aC{i});
is_init4 = ~isempty(LP_oC{i});
is_init5 = ~isempty(LP_SC{i});
if ~is_init1 || ~is_init2 || ~ is_init3 || ~is_init4 || ~is_init5
  error('This routine needs global data which must be generated by calling ''munu_s_i'' first.');
end 


if tr=='N'
  Y(LP_oC{i},:) = LP_UC{i}\(LP_LC{i}\(LP_SC{i}(:,LP_aC{i})\(LP_ML*X)));
  Y = LP_MU*Y;
elseif tr=='T'
  X = LP_MU'*X;
  Y = (LP_SC{i}(:,LP_aC{i}))'\(LP_LC{i}'\(LP_UC{i}'\(X(LP_oC{i},:))));
  Y = LP_ML'*Y;
else
  error('tp must be either ''N'' or ''T''.');
end



