#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>
#include <iomanip>
#include <sstream> // Libreria per stringstream

int main(int argc, char *argv[]) {
    if (argc < 4) {
        std::cerr << "Usage: " << argv[0] << " <output_path> <Imin> <Imax>\n";
        return 1;
    }

    std::cout << "Begin the matching.\n";

    std::string path_out = argv[1];
    if (path_out.back() != '/') {
        path_out += "/";
    }
    int Imin = std::stoi(argv[2]);
    int Imax = std::stoi(argv[3]);

    for (int k = Imin; k <= Imax; ++k) {
        std::ifstream header_file(path_out + "CH2_" + std::to_string(k) + ".dat");
        std::string header_lines[2];
        if (header_file.is_open()) {
            std::getline(header_file, header_lines[0]); // Leggi la prima riga di intestazione
            std::getline(header_file, header_lines[1]); // Leggi la seconda riga di intestazione
            header_file.close();
        } else {
            std::cerr << "Unable to open file: " << path_out + "CH2_" + std::to_string(k) + ".dat\n";
            continue;
        }

        std::ifstream data_file1(path_out + "CH2_" + std::to_string(k) + ".dat");
        std::ifstream data_file2(path_out + "CH1_" + std::to_string(k) + ".dat");
        std::vector<double> x1, y1, x2, y2;

        // Ignora le righe di intestazione
        std::string line;
        std::getline(data_file1, line);
        std::getline(data_file1, line);
        std::getline(data_file2, line);
        std::getline(data_file2, line);

        if (data_file1.is_open() && data_file2.is_open()) {
            double x, y;
            while (data_file1 >> x >> y) {
                x1.push_back(x);
                y1.push_back(y);
            }
            while (data_file2 >> x >> y) {
                x2.push_back(x);
                y2.push_back(y);
            }
            data_file1.close();
            data_file2.close();
        } else {
            std::cerr << "Unable to open data file CH2_" << k << ".dat or CH1_" << k << ".dat\n";
            continue;
        }

        int m = x1.size();
        int n = x2.size();
        std::vector<double> y_out(n);

        std::cout << "File " << k << "#\n";
        for (int i = 0; i < n; ++i) {
            // Trova l'indice del punto più vicino in x1 per il punto corrente in x2
            int min_index = 0;
            double min_distance = std::abs(x1[0] - x2[i]);
            for (int j = 1; j < m; ++j) {
                double distance = std::abs(x1[j] - x2[i]);
                if (distance < min_distance) {
                    min_distance = distance;
                    min_index = j;
                }
            }

            // Esegui l'interpolazione
            if (min_index == 0) {
                y_out[i] = y1[min_index];
            } else if (min_index == m - 1) {
                y_out[i] = y1[min_index];
            } else {
                // Interpolazione lineare
                double alpha = (x2[i] - x1[min_index - 1]) / (x1[min_index] - x1[min_index - 1]);
                y_out[i] = y1[min_index - 1] + alpha * (y1[min_index] - y1[min_index - 1]);
            }
        }

        std::ofstream file_out(path_out + "CH2_" + std::to_string(k) + ".dat");
        if (file_out.is_open()) {
            file_out << header_lines[0] << "\n";
            file_out << header_lines[1] << "\n";
            for (int i = 0; i < n; ++i) {
                file_out << std::fixed << std::setprecision(6) << x2[i] << "\t" << y_out[i] << "\n";
            }
            file_out.close();
        } else {
            std::cerr << "Unable to create output file: " << path_out + "CH2_" + std::to_string(k) + ".dat\n";
            continue;
        }
    }

    std::cout << "Matching completed. Click \"check\" to control the number of lines.\n";
    return 0;
}
