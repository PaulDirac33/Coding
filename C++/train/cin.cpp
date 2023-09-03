#include <iostream>
#include <string>
using namespace std;

int main()
{
    int numero1, numero2;
    string operazione = "";
    cout << "Inserisci un numero, un'operazione ed un secondo numero:\n";
    cin >> numero1;
    cout << "";
    cin >> operazione;
    cout << "";
    cin >> numero2;
    cout << "\nRisultato: ";
    if (operazione == "+")
    {
        cout << numero1 + numero2;
    }
    else if (operazione == "-")
    {
        cout << numero1 - numero2;
    }
    else if (operazione == "*")
    {
        cout << numero1 * numero2;
    }
    else if (operazione == "/")
    {
        if (numero2 != 0)
        {
            cout << numero1 / numero2;
        }
        else
        {
            cout << "Errore: divisione per zero!";
        }
    }
    else
    {
        cout << "Operazione non valida!";
    }
    cout << "\n";
    return 0;
}
