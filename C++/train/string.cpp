#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

int main()
{
	string parola, parola2;

	cout << "Insert first word: ";
	cin >> parola;
	cout << parola << "\n";
	cin.ignore(numeric_limits<streamsize>::max(), '\n');
	cout << "Insert second word: ";
	getline(cin, parola2);
	cout << parola2 << "\n";

	int lenght = parola.size();
	int lenght2 = parola2.size();
	cout << "\n";
	cout << "1): ";
	int i;
	for (i = 0; i < lenght; i++)
	{
		cout << parola[i];
	}
	cout << "\n";
	cout << "2): ";
	for (i = 0; i < lenght2; i++)
	{
		cout << parola2[i];
	}
	cout << "\n";
	return 0;
}