#include <iostream>
#include <string>
#include <iomanip>
#include <fstream>
#include <cmath>
#include <chrono>
using namespace std;

int main(){
	int N;
	float an = 0;
	float an_prev, Time;
    cout << "Insert N: ";
    cin >> N;
    ofstream file("series.dat");
    file << "n" << "\t" << "Σ(1/n^2)" << endl;   
    chrono::steady_clock::time_point tic = chrono::steady_clock::now();
    int n;
    for (n = 1; n <= N; n++){
    	an += pow(n,-2);
    	file << n << "\t" << fixed << setprecision(9) << an << endl;
    	if (n > 1 and abs(an_prev - an) <= pow(10,-6)){
    		break;
    	}
    	an_prev = an;
    }
    file.close();
    chrono::steady_clock::time_point toc = chrono::steady_clock::now();
    chrono::milliseconds duration = chrono::duration_cast<chrono::milliseconds>(toc - tic);
    Time = duration.count();
    cout << "Tempo impiegato: " << Time << " ms" << endl;
	return 0;
}