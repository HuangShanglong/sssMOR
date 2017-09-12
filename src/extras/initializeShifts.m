function s0 = initializeShifts(sys,Opts)
% initializeShifts - initialize Shifts for global and consecutive MOR
% 
% Syntax:
%		s0                  = initializeShifts(sys,Opts)
% 
% Description:
%       
%       Generate a column vector consisting of sets of starting points in each row 
%       based on chosen strategy.
%       
% Input Arguments:
%		*Required Input Arguments:*
%       -sys: An sss-object containing the LTI system
%
%		*Optional Input Arguments:*
%		-Opts:              A structure containing following fields
%			-.strategy:  	strategy for shift generation;
%                           [ADI / const / ROM / {eigs} / 
%                            linspaced / logspaced / random / lognrnd]
%                           mixed strategy for real and imag part possible 
%			-.nShifts:  	number of shifts;
%                           [{2} / positive integer]
%			-.nSets:        number of shift vectors;
%                           [{10} / positive integer]
%			-.shiftTyp:  	typ of shifts;
%                           [{'conj'} / 'real' / imag]
%			-.omegamin:  	lower bound of generated shifts;
%                           [{|eigs(sys,'sm')|}, positive double]
%			-.omegamax:  	upper bound of generated shifts;
%                           [{|eigs(sys,'lm')|}, positive double]
%			-.kp:           number of Arnoldi steps for ADI
%                           [{40} / 20...80 ]
%			-.km:           number of Arnoldi steps for ADI
%                           [{40} / 10...40 ]
%			-.eigsTyp:  	choice of eigenvalues for eigs and ROM;
%                           [{'sm'} / 'lm' / 'li' / 'si'/ 'lr' / 'sr' / 'la' / 'sa']
%			-.constValue:  	value for constant shift strategy;
%                           [{0} / double]
%			-.offset:       offset for plain imag or real shifts 
%                           [{0} / double]
%           -.format:       output format of the shifts
%                           [{complex} / ab]
%
% Output Arguments:
%       -s0:            Vector of sets of starting points 
%
% Examples:
%       By default, initializeShifts generates a matrix with 10 vector of
%       2 shifts (rows) with the eigs strategy.
%> sys = loadSss('building');
%> s0 = initializeShifts(sys); plot(complex(s0'),'x');
%
%       The behavior of the function can be customized using the
%       option structure Opts, e.g. mixed strategies with logspaced real 
%       and linspaced imag part of the shifts
%> Opts = struct('strategy',{{'logspaced','linspaced'}});
%> s0 = initializeShifts(sys,Opts); plot(complex(s0'),'x');
%
% See Also: 
%		cure, cirka, spark
%
% References:
%		[1] Michael Ott (2016)*, Strategien zur Initialisierung der Entwicklungspunkte f�r H2-optimale Modellordnungsreduktion
%
%------------------------------------------------------------------
% This file is part of <a href="matlab:docsearch sssMOR">sssMOR</a>, a Sparse State-Space, Model Order 
% Reduction and System Analysis Toolbox developed at the Chair of 
% Automatic Control, Technische Universitaet Muenchen. For updates 
% and further information please visit <a href="https://www.rt.mw.tum.de/?sssMOR">www.rt.mw.tum.de/?sssMOR</a>
% For any suggestions, submission and/or bug reports, mail us at
%                   -> <a href="mailto:sssMOR@rt.mw.tum.de">sssMOR@rt.mw.tum.de</a> <-
%
% More Toolbox Info by searching <a href="matlab:docsearch sssMOR">sssMOR</a> in the Matlab Documentation
%
%------------------------------------------------------------------
% Authors:      Michael Ott, Siyang Hu
% Email:        <a href="mailto:morlab@rt.mw.tum.de">morlab@rt.mw.tum.de</a>
% Website:      <a href="https://www.rt.mw.tum.de/">www.rt.mw.tum.de</a>
% Work Adress:  Technische Universitaet Muenchen
% Last Change:  13 Jul 2017
% Copyright (c) 2017 Chair of Automatic Control, TU Muenchen
%------------------------------------------------------------------

Def.strategy    ='eigs';                %initialisation strategy
Def.nShifts     =2;                     %Number of shifts
Def.nSets       =10;                    %Number of shift vectors 
Def.constValue  =0;                     %constant shift
Def.omegamin    =abs(eigs(sys,1,'sm')); %lower bound  
Def.omegamax    =abs(eigs(sys,1));      %upper bound
Def.kp          =40;                    %number of Arnoldi steps
Def.km          =25;                    %number of Arnoldi steps
Def.eigsType    ='sm';                  %eigs parameter
Def.shiftTyp    ='conj';                %plain imaginary shifts
Def.offset      =0;                     %global offset for shifts
Def.format      ='complex';             %output format

%create the options structure                 %aus CURE �bernommen
if ~exist('Opts','var') || isempty(Opts)
    Opts = Def;
else
    Opts = parseOpts(Opts,Def);
end

% check for valid combination of strategies
if ~iscell(Opts.strategy)
    Opts.strategy = {Opts.strategy};
else
    if (any(strcmp(Opts.strategy{1},{'ADI','eigs','ROM','const'}))...
            ||any(strcmp(Opts.strategy{end},{'ADI','eigs','ROM','const'})))...
            && (length(Opts.strategy) > 1 || ~strcmp(Opts.shiftTyp,'conj'))
        error('invalid choice of strategy');
    end
end

% dealing with odd number Opts.nShifts
oddOrder = 0;

if mod(Opts.nShifts,2)
   Opts.nShifts = Opts.nShifts + 1;
   oddOrder = 1;
end

switch Opts.strategy{1}
    
    case 'constant'
        s0=Opts.constValue*ones(Opts.nSets,Opts.nShifts);
        
    case 'eigs'
        s0=-(eigs(sys,Opts.nShifts*Opts.nSets,Opts.eigsType))';
        idxUnstable=real(s0)<0;   %Spiegeln,falls instabile eigs
        s0(idxUnstable)=-s0(idxUnstable);
        try
            cplxpair(s0);
        catch
            s0(end)=real(s0(end));
        end
        s0 = reshape(s0,Opts.nShifts,Opts.nSets)';
        
    case 'ADI'
        Opts.method='heur';
        Def.adi= 0; %use only adi or lyapunov equation ('0','adi','lyap')
        Def.lse= 'gauss'; %lse (used only for adi)
        
        if ~exist('Opts','var') || isempty(Opts)
            Opts = Def;
        else
            Opts = parseOpts(Opts,Def);
        end
        
        if ~sys.isDae
            % options for mess
            % eqn struct: system data
            eqn=struct('A_',sys.A,'E_',sys.E,'B',sys.B,'C',sys.C,'type','N','haveE',sys.isDescriptor);
            
            % opts struct: mess options
            messOpts.adi=struct('shifts',struct('l0',Opts.nShifts*Opts.nSets,'kp',Opts.kp,'km',Opts.km,'b0',ones(sys.n,1),...
                'info',0,'method',Opts.method),'maxiter',300,'restol',0.1,'rctol',1e-12,...
                'info',0,'norm','fro');
            
            % user functions: default
            if strcmp(Opts.lse,'gauss')
                oper = operatormanager('default');
            elseif strcmp(Opts.lse,'luChol')
                if sys.isSym
                    oper = operatormanager('chol');
                else
                    oper = operatormanager('lu');
                end
            end
        end
        
        
        % get adi shifts
        [messOpts.adi.shifts.p, ~]=mess_para(eqn,messOpts,oper);
        
        s0=messOpts.adi.shifts.p;
        
        
        %Spiegeln
        idxUnstable = real(s0)<0;
        s0(idxUnstable) = - s0(idxUnstable);
        
        %Abschneiden (des letzten rein reellen shifts falls  s0 zu lang)
        if(length(s0)>Opts.nShifts*Opts.nSets)
            reals0=find((imag(s0)==0));
            if(~isempty(reals0))
                s0(reals0(end))=[];
            else
                error('Abschneiden funktioniert nicht, s0 zu lang')
            end
        end
        
        s0 = reshape(s0,Opts.nShifts,Opts.nSets)';
        
    case 'ROM'
        
        mineig=-eigs(sys,1,'sm'); %Verwendung des gespiegelten Eigenwerts!
        
        if(~isreal(mineig))
            
            multip = ceil(Opts.nShifts*Opts.nSets/2);
            sysr = rk(sys,[mineig,conj(mineig);multip, multip],[mineig,conj(mineig);multip,multip]);
            s0 = -eig(sysr).';
            if length(s0)> Opts.nShifts*Opts.nSets
                idx = find(imag(s0)==0);
                if isempty(idx)
                    s0=sort(s0);
%                     s0(end) = [];
%                     if imag(s0(end))~=0
%                         s0(end) = real(s0(end));
%                     end
                else
                    [~,idx2] = sort(abs(s0(idx))); %ascend
                    s0(idx(idx2(end))) = [];
                end
            end
            
        else
            sysr = rk(sys,[mineig;Opts.nShifts],[mineig;Opts.nShifts]);
            s0 = eig(sysr).';
        end
        
        idxUnstable=real(s0)<0;   %Spiegeln,falls instabile eigs
        s0(idxUnstable)=-s0(idxUnstable);
        s0 = reshape(s0,Opts.nShifts,Opts.nSets)';
    
    
    otherwise
        % grid and random based strategies
        
        % check for valid combination of strategeis
        if length(Opts.strategy)==1 && strcmp(Opts.shiftTyp,'conj')
            Opts.strategy = [Opts.strategy; Opts.strategy];
        elseif ~strcmp(Opts.shiftTyp,'conj') && length(Opts.strategy)>1
            error('invalid choice of strategy');
        end
        
        % compute grid size and grid parameters
        if strcmp(Opts.shiftTyp,'conj')
            iSplit = ceil(sqrt(Opts.nShifts*Opts.nSets/2));
            NoS = Opts.nShifts*Opts.nSets/2;
        elseif strcmp(Opts.shiftTyp,'imag')
            iSplit = Opts.nShifts*Opts.nSets/2;
            NoS = iSplit;
        else
            iSplit = Opts.nShifts*Opts.nSets;
            if Opts.offset ~= 0
               iSplit = iSplit/2;
            end
            NoS = iSplit;
        end
        
        for ii = 1:length(Opts.strategy)
            switch Opts.strategy{ii}
                case 'linspaced'
                    s0_temp=linspace(Opts.omegamin,Opts.omegamax,iSplit);
                    s0_parts{ii} = s0_temp;
                    
                case 'logspaced'
                    s0_temp=logspace(log10(Opts.omegamin),log10(Opts.omegamax),iSplit);
                    s0_parts{ii} = s0_temp;
                    
                case 'random'
                    s0_temp=Opts.omegamin+rand(1,NoS)*(Opts.omegamax-Opts.omegamin);
                    s0_parts{ii} = s0_temp;
                    
                case 'lognrnd'
                    s0_temp = lognrnd(log(max(Opts.omegamin,1)),(log(Opts.omegamax)-log(max(Opts.omegamin,1)))/2.576,1,NoS);       
                    s0_parts{ii} = s0_temp;
                    
                otherwise
                    error('unknown initalisation strategy');
            end
        end
        
        %generate final s0 matrix
        if ~strcmp(Opts.shiftTyp,'real')
            if strcmp(Opts.shiftTyp,'conj')
                if  ~isempty(strfind(Opts.strategy{1},'spaced'))
                    s0_real = repelem(s0_parts{1},2*iSplit);
                    s0_real = s0_real(1:Opts.nShifts*Opts.nSets);
                else
                    s0_real = repelem(s0_parts{1},2);
                end
            else
                s0_real = Opts.offset;
            end
            if  ~isempty(strfind(Opts.strategy{end},'spaced'))
                s0_imag = repmat(repelem(s0_parts{end},2).*repmat([1,-1],1,iSplit),1,iSplit)*1i;
                s0_imag = s0_imag(1:Opts.nShifts*Opts.nSets);
            else
                s0_imag = repelem(s0_parts{end},2).*repmat([1,-1],1,NoS)*1i;
            end
            s0 = s0_real + s0_imag;
        else
            if Opts.offset ~= 0
                s0 = repelem(s0_parts{:},2)+Opts.offset*repmat([1,-1],1,NoS)*1i;
            else
                s0 = s0_parts{:};
            end
        end
        
        s0 = reshape(s0,Opts.nShifts,Opts.nSets)';
end

% plain real shifts at the end, when the number of shifts is odd
if oddOrder
    s0(:,end) = [];
    s0(:,end) = real(s0(:,end));
end

% change output format to ab
if strcmp(Opts.format,'ab')
    s0 = s2p(s0(:,1),s0(:,2));
end

end

%% ------------------ AUXILIARY FUNCTIONS --------------------------

function varargout = s2p(varargin)
% s2p: Shifts to optimization parameters for spark
% ------------------------------------------------------------------
% USAGE:  This function computes the two paramters a,b that are used within
% the optimization in spark.
%
% p = s2p(s)
% [a,b] = s2p(s1,s2)
%
% Computations:
% a = (s1+s2)/2
% b = s1*s2
%
% s1 = a + sqrt(a^2-b)
% s2 = a - sqrt(a^2-b)
%
% See also CURE, SPARK.
%
% ------------------------------------------------------------------
% REFERENCES:
% [1] Panzer (2014), Model Order Reduction by Krylov Subspace Methods
%     with Global Error Bounds and Automatic Choice of Parameters
% ------------------------------------------------------------------
% This file is part of MORLab, a Sparse State Space, Model Order
% Reduction and System Analysis Toolbox developed at the Institute
% of Automatic Control, Technische Universitaet Muenchen.
% For updates and further information please visit www.rt.mw.tum.de
% For any suggestions, submission and/or bug reports, mail us at
%                      -> MORLab@tum.de <-
% ------------------------------------------------------------------
% Authors:      Alessandro Castagnotto
% Last Change:  27 April 2015
% ------------------------------------------------------------------

% parse input
if nargin==1
    s1 = varargin{1}(1);
    s2 = varargin{1}(2);
else
    s1 = varargin{1};
    s2 = varargin{2};
end

% compute
a = (s1+s2)/2;
b = s1.*s2;

% generate output
if nargout<=1
    varargout{1} = [a,b];
else
    varargout{1} = a;
    varargout{2} = b;
end
end
    