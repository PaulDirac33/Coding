#include <iostream>
#include <string>
#include <iomanip>
#include <fstream>
using namespace std;

int main()
{
	string prova = "I am Lord Voldemort";
	ofstream file("t.txt");
	file << prova << endl;
	return 0;
}