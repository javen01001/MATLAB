clc; clear all; close all; color = 'kbgrcmy'; colorVal=1;

% Min Max of the robots start position
robotX = [-8 8];
robotY = [-8 8];

% Generate Random Start Points for Robots
numberOfRobots=7;
robot=[ randi(robotX,numberOfRobots,1) ...
        randi(robotY,numberOfRobots,1)]

% load figure and set axis
figure; hold on; grid on;
axis([-10 30 -10 20]); axis square; axis equal;

% Create Animated Line Objects for Each robot, different colors
robotTrajectory = [animatedline('Color',color(colorVal),'LineWidth',2)];
for i = 1: numberOfRobots-1
   colorVal = colorVal+1;
   if(colorVal>7)
       colorVal=1;
   end
   robotTrajectory = [robotTrajectory;animatedline('Color',color(colorVal),'LineWidth',2)];
end

%Robot/Algorithm related constants
M=1;
B=1;
kd=9;
ksk=1;
kr=0.15;
alpha=2;
qk=2.5;
%Charges on each robot
q(1:numberOfRobots)=qk;
%Mass of each robot
m(1:numberOfRobots)=M;
%Electrostatic Constant
K=10;

% Force Threshold, robots stop moving if force < threshold
FORCE_THRESHOLD = 0.7

xdot = zeros(numberOfRobots,1);
ydot = zeros(numberOfRobots,1);

% Load Trajectory for Virtual Leader bot
load('trajectory.mat')

% Load First Trajectory point and Draw Circle Around it
VirtualBot=trajectory(1,:);
circle(VirtualBot(1,1),VirtualBot(1,2),alpha);
VirtualTrajectory = animatedline('Color','r','LineWidth',2,'LineStyle','-.')

% Draw a border around the robots
border(robot(:,1),robot(:,2));


Fxk_dist = zeros(numberOfRobots,numberOfRobots);
Fxk = zeros(1,numberOfRobots);
Attractive_Force_x = zeros(1,numberOfRobots);
FxkVS = zeros(1,numberOfRobots);

Fyk_dist = zeros(numberOfRobots,numberOfRobots);
Fyk = zeros(1,numberOfRobots);
Attractive_Force_y = zeros(1,numberOfRobots);
FykVS = zeros(1,numberOfRobots);




%Main LOOP
WayPoint = 1;
while WayPoint<(length(trajectory)-1)
    VirtualBot=trajectory(WayPoint,:);

    % Vector keep track of how many robots still moving
    % If all go to ZERO, Virtual Bot moves to NEXT WayPoint
    movement = ones(numberOfRobots,1);
    
    iterations = 0; % Variable to track iterations in each inner loop
    
    % Inner Loop
    while sum(movement)>0
        iterations = iterations+1;
        
        %Computing distance of individual robot from all other robots
        r=zeros(numberOfRobots,numberOfRobots);
        for i=1:numberOfRobots
            for j=1:numberOfRobots
                a=robot(i,:)-robot(j,:);
                r(i,j)=sqrt(a(1)^2+a(2)^2);
            end
        end
        
        %Computing orientation of individual from all other robots
        theta=zeros(numberOfRobots,numberOfRobots);
        for i=1:numberOfRobots
            for j=1:numberOfRobots
                if i==j
                    theta(i,j)=0;
                elseif i~=j
                    a=robot(i,:)-robot(j,:);
                    theta(i,j)=atan2(a(2),a(1));
                end
            end
        end
        
        %     Computing Electrostatic forces (Repulsive) on individual robot
        %     from all other robots
        Electrostatic_Forces=zeros(numberOfRobots,numberOfRobots);
        for i=1:numberOfRobots
            for j=1:numberOfRobots
                if i==j
                    Electrostatic_Forces(i,j)=0;
                elseif i~=j
                    Electrostatic_Forces(i,j)=(K*q(i)*q(j))/(r(i,j)^2);
                end
            end
        end
        
        %Decomposition of Electrostatic forces in x and y components
        for i=1:numberOfRobots
            for j=1:numberOfRobots
                Fxk_dist(i,j)=Electrostatic_Forces(i,j)*cos(theta(i,j));
                Fyk_dist(i,j)=Electrostatic_Forces(i,j)*sin(theta(i,j));
            end
        end
        
        for i=1:numberOfRobots
            Fxk(i)=sum(Fxk_dist(i,1:numberOfRobots));
            Fyk(i)=sum(Fyk_dist(i,1:numberOfRobots));
        end
        
        %Computing x and y components of Attractive Force (Equation 8 in JP)
        for i=1:numberOfRobots
            a=robot(i,:)-VirtualBot;
            Attractive_Force_x(i)=ksk*(a(1)*(a(1)^2+a(2)^2-alpha^2));
            Attractive_Force_y(i)=ksk*(a(2)*(a(1)^2+a(2)^2-alpha^2));
        end
        
        %Computing resultant forces on each robot
        for i=1:numberOfRobots
            FxkVS(i)=Fxk(i)-Attractive_Force_x(i);
            FykVS(i)=Fyk(i)-Attractive_Force_y(i);
        end
        
        for i=1:numberOfRobots
            x_pos_new = robot(i,1);
            y_pos_new = robot(i,2);
            
            if(abs(FxkVS(i))>FORCE_THRESHOLD)
                fx = @(t,x) [x(2); (FxkVS(i)-(B+kd)*x(2))/M];
                [T,X]=ode45(fx,[0,0.05],[robot(i,1);xdot(i)]);
                [m,z] = size(X);
                x_pos_new=X(m,1);
                xdot(i)=X(m,2);
            end
            
            if(abs(FykVS(i))>FORCE_THRESHOLD)
                fy = @(t,y) [y(2); (FykVS(i)-(B+kd)*y(2))/M];
                [T,Y]=ode45(fy,[0,0.05],[robot(i,2);ydot(i)]);
                [m,z] = size(Y);
                y_pos_new=Y(m,1);
                ydot(i)=Y(m,2);
            end
            
            if abs(FxkVS(i))<=FORCE_THRESHOLD &&  abs(FykVS(i))<=FORCE_THRESHOLD
                movement(i,1) = 0;
            elseif abs(FxkVS(i))>FORCE_THRESHOLD || abs(FykVS(i))>FORCE_THRESHOLD
                 movement(i,1) = 1;
            end
            
            robot(i,:)=[x_pos_new y_pos_new];
            addpoints(robotTrajectory(i),x_pos_new,y_pos_new);
            addpoints(VirtualTrajectory,VirtualBot(1,1),VirtualBot(1,2));
        end
            drawnow
    end
    
   
    if(mod(WayPoint,20)==0)
        border(robot(:,1),robot(:,2));
%         circle(VirtualBot(1,1),VirtualBot(1,2),alpha);
        drawnow
    end
    
    WayPoint = WayPoint+1
end