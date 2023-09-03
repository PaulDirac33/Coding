#include <iostream>
#include <string>
#include <iomanip>
#include <fstream>
#include <cmath>
#include <chrono>
using namespace std;

int main(){
	int N;
	float Time;
	string N_tot;
    cout << "\nInsert how many prime numbers you want to generate:  ";
    getline(cin, N_tot);
    N = stoi(N_tot);
    chrono::steady_clock::time_point tic = chrono::steady_clock::now();
    ofstream f_num("prime.dat");
	ofstream f_diff("primediff.dat");
	f_num << "n\tp_{(n)}\n";
	f_num << " \tPrime numbers\n";
	f_num << "1\t2\n";
	f_diff << "n\t∆_{(n)}\n";
	f_diff << " \tp_{n+1} - p_n\n";
	f_diff << "1\t2\n";
	int n = 1;
	int p = 2;
	int i = 3;
	string found = "no";
	while (n <= N - 1){
		int j;
		for (j = 2; j < i; j++){
			if (i % j == 0){
				found = "yes";		// found a divisor
				break;
			}
		}
		if (found == "no"){
			f_diff << n << "\t" << i - p << "\n";
			p = i;
			n++;
			f_num << n << "\t" << i << "\n";
			i++;
		} else{
			found = "no";
			i++;
		}
	}	
	chrono::steady_clock::time_point toc = chrono::steady_clock::now();
	chrono::milliseconds duration = chrono::duration_cast<chrono::milliseconds>(toc - tic);
    Time = duration.count()/1000.0;
	cout << "Execution time:  " << fixed << setprecision(3) << Time << " s\n";
	cout << endl;
	f_num.close();
	f_diff.close();
    return 0;
}