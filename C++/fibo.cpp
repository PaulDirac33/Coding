#include <iostream>
#include <string>
#include <iomanip>
#include <fstream>
using namespace std;

int main()
{
    float a, b, c;
    int N;
    cout << "Insert N: ";
    cin >> N;
    ofstream file("fibonacci.dat");
    ofstream file2("phi.dat");
    file << "n" << "\t" << "f(n)" << endl;
    file2 << "n" << "\t" << "𝜙(n)" << endl;
    file << "\t" << "Fibonacci series" << endl;
    file2 << "\t" << "Golden ratio" << endl;
    a = 0;
    b = 1;
    file << 1 << "\t" << a << endl;
    file << 2 << "\t" << b << endl;
    // cout << "Primi " + to_string(N) + " numeri della serie di Fibonacci:\n";
    // cout << left << setw(10) << "i = 1" << "--> " << right << setw(6) << a << "\n";
    // cout << left << setw(10) << "i = 2" << "--> " << right << setw(6) << b << "\n";
    int i = 3;
    while (i <= N) {
        c = a + b;
        // cout << left << setw(10) << "i = " + to_string(i) << "--> " << right << setw(6) << c << "\n";
        file << i << "\t" << c << endl;
        file2 << i - 2 << "\t" << fixed << setprecision(9) << c/b << endl;
        a = b;
        b = c;
        i++;
    }
    file.close();
    file2.close();
    return 0;
}
