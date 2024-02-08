#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>

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
            std::getline(header_file, header_lines[0]);
            std::getline(header_file, header_lines[1]);
            header_file.close();
        } else {
            std::cerr << "Unable to open file: " << path_out + "CH2_" + std::to_string(k) + ".dat\n";
            continue;
        }

        std::ifstream data_file1(path_out + "CH2_" + std::to_string(k) + ".dat");
        std::ifstream data_file2(path_out + "CH1_" + std::to_string(k) + ".dat");
        std::vector<double> x1, y1, x2, y2;
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
            std::vector<double> d(m);
            for (int j = 0; j < m; ++j) {
                d[j] = std::abs(x1[j] - x2[i]);
            }

            auto min_index = std::min_element(d.begin(), d.end()) - d.begin();
            int j1, j2;
            if (x2[i] - x1[min_index] > 0) {
                j2 = min_index;
                j1 = j2 - 1;
            } else if (x2[i] - x1[min_index] < 0) {
                j1 = min_index;
                j2 = j1 + 1;
            } else {
                j2 = min_index;
                j1 = j2;
            }

            if (j1 == j2) {
                y_out[i] = y1[j1];
            } else {
                y_out[i] = y1[j2] + (x2[i] - x1[j2]) * ((y1[j2] - y1[j1]) / (x1[j2] - x1[j1]));
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
