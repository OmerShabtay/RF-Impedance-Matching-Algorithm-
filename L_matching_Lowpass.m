clear; clc; close all;

f = 2.4e9;             
Z0 = 50;               
RL = 60;               
XL = 30;               
ZL = RL + 1i*XL;       
YL = 1 / ZL;           

cap_files = dir('R05*.s2p');
if isempty(cap_files)
    error('No capacitor files found. Ensure they start with "R05".');
end

ind_files = [dir('04CS*.s2p'); dir('04CS*.S2P')];
if isempty(ind_files)
    error('No inductor files found starting with "04CS".');
end

num_caps = length(cap_files);
num_inds = length(ind_files);
fprintf('Running 2D Sweep: %d Capacitors vs %d Inductors (Total: %d combinations)\n', ...
        num_caps, num_inds, num_caps * num_inds);

S11_matrix = zeros(num_caps, num_inds);

for c = 1:num_caps
    cap_name = cap_files(c).name;
    try
        C_data = sparameters(cap_name);
        C_zparams = zparameters(C_data);
        Z11_vec_cap = rfparam(C_zparams, 1, 1);
        Z_shunt_cap = interp1(C_zparams.Frequencies, Z11_vec_cap, f); 
        Y_shunt_cap = 1 / Z_shunt_cap;
        
        Yp = YL + Y_shunt_cap;
        Zp = 1 / Yp; 
    catch
        S11_matrix(c, :) = NaN;
        continue;
    end
    
    for l = 1:num_inds
        ind_name = ind_files(l).name;
        try
            L_data = sparameters(ind_name);
            L_yparams = yparameters(L_data);
            Y11_vec_ind = rfparam(L_yparams, 1, 1);
            Y11_ind = interp1(L_yparams.Frequencies, Y11_vec_ind, f);
            Z_series_ind = 1 / Y11_ind;
            
            Zin = Zp + Z_series_ind;
            
            Gamma = (Zin - Z0) / (Zin + Z0);
            S11_matrix(c, l) = 20 * log10(abs(Gamma));
        catch
            S11_matrix(c, l) = NaN; 
        end
    end
end

[min_val, linear_idx] = min(S11_matrix(:));
[best_cap_idx, best_ind_idx] = ind2sub([num_caps, num_inds], linear_idx);

best_cap = cap_files(best_cap_idx).name;
best_ind = ind_files(best_ind_idx).name;

fprintf('\n=== 2D Optimization Complete ===\n');
fprintf('Optimal Shunt Capacitor: %s\n', best_cap);
fprintf('Optimal Series Inductor: %s\n', best_ind);
fprintf('Best S11 Achieved: %.2f dB\n', min_val);

figure('Name', 'Low-Pass S11 Optimization Surface', 'Color', 'w');
surf(1:num_inds, 1:num_caps, S11_matrix);
shading interp;
colormap jet;
colorbar;
xlabel('Inductor Index', 'FontWeight', 'bold');
ylabel('Capacitor Index', 'FontWeight', 'bold');
zlabel('S_{11} (dB)', 'FontWeight', 'bold');
title('Low-Pass Matching Network Performance Space');
view(-45, 45);