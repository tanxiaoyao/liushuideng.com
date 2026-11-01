---
title: "多层最短路"
published: 2025-05-08
description: ""
image: ""
tags: []
category: ""
draft: false
---

```cpp
#include <iostream>
#include <vector>
#include <limits>
#include <tuple>
#include <cstdlib>
#include <chrono>
#include <algorithm> // 用于 make_heap, push_heap, pop_heap
#include <unordered_map>

using namespace std;

// 定义一个常量表示无穷大
const int INF = numeric_limits<int>::max();

// 定义一个结构体表示图中的边
struct Edge {
    int to;     // 目标节点
    int cost;   // 边的代价
};

// 自定义二叉堆
class BinaryHeap {
public:
    using Element = tuple<int, int, int>; // (当前代价, 当前层, 当前节点)

    // 插入元素
    void push(const Element& element) {
        heap.push_back(element);
        push_heap(heap.begin(), heap.end(), compare);
    }

    // 弹出最小元素
    void pop() {
        pop_heap(heap.begin(), heap.end(), compare);
        heap.pop_back();
    }

    // 获取最小元素
    Element top() const {
        return heap.front();
    }

    // 判断堆是否为空
    bool empty() const {
        return heap.empty();
    }

private:
    vector<Element> heap;

    // 比较函数，用于实现最小堆
    static bool compare(const Element& a, const Element& b) {
        return get<0>(a) > get<0>(b); // 按代价升序排列
    }
};

// 修改后的 Dijkstra 算法
using InterLayerConnections = vector<unordered_map<int, vector<pair<int, int>>>>;

void dijkstra(int startLayer, int startNode, const vector<vector<vector<Edge>>>& graph,
    const InterLayerConnections& interLayerCost, vector<vector<int>>& minCost) {
    int layers = graph.size();
    int nodes = graph[0].size();

    // 自定义二叉堆，存储 (当前代价, 当前层, 当前节点)
    BinaryHeap pq;

    // 初始化最小代价数组
    for (int i = 0; i < layers; ++i) {
        fill(minCost[i].begin(), minCost[i].end(), INF);
    }

    // 将起始节点加入队列
    minCost[startLayer][startNode] = 0;
    pq.push({ 0, startLayer, startNode });

    // Dijkstra 主循环
    while (!pq.empty()) {
        auto [currentCost, currentLayer, currentNode] = pq.top();
        pq.pop();

        // 如果当前代价大于已记录的最小代价，跳过
        if (currentCost > minCost[currentLayer][currentNode]) continue;

        // 遍历当前层的邻接节点
        for (const auto& edge : graph[currentLayer][currentNode]) {
            int nextNode = edge.to;
            int nextCost = currentCost + edge.cost;

            if (nextCost < minCost[currentLayer][nextNode]) {
                minCost[currentLayer][nextNode] = nextCost;
                pq.push({ nextCost, currentLayer, nextNode });
            }
        }

        // 遍历层间连接
        if (interLayerCost[currentLayer].count(currentNode)) {
            for (const auto& [nextLayer, cost] : interLayerCost[currentLayer].at(currentNode)) {
                int nextCost = currentCost + cost;
                if (nextCost < minCost[nextLayer][currentNode]) {
                    minCost[nextLayer][currentNode] = nextCost;
                    pq.push({ nextCost, nextLayer, currentNode });
                }
            }
        }
    }
}

int main() {
    // 示例输入数据
    int layers = 240;  // 层数
    int nodes = 1000;  // 每层的节点数

    // 每层的图结构 (层 -> 节点 -> 边)
    vector<vector<vector<Edge>>> graph(layers, vector<vector<Edge>>(nodes));

    // 构造每层的边，尽量构造平面图
    for (int layer = 0; layer < layers; ++layer) {
        for (int node = 0; node < nodes; ++node) {
            // 每个节点连接到下一个节点，形成一个环
            int nextNode = (node + 1) % nodes;
            graph[layer][node].push_back({ nextNode, rand() % 10 + 1 }); // 随机权重1-10

            // 添加额外的边，确保每层有5000条边以上
            for (int i = 0; i < 5; ++i) {
                int randomNode = rand() % nodes;
                if (randomNode != node) {
                    graph[layer][node].push_back({ randomNode, rand() % 10 + 1 });
                }
            }
        }
    }

    // 定义层间连接关系的稀疏存储结构
    InterLayerConnections interLayerCost(layers);

    // 构造层间连接代价
    for (int layer = 0; layer < layers - 1; ++layer) {
        for (int node = 0; node < nodes; ++node) {
            // 只有三分之一的节点有层间连接
            if (rand() % 3 == 0) {
                int cost = rand() % 2000 + 1000; // 随机权重1000-3000
                interLayerCost[layer][node].push_back({ layer + 1, cost }); // 当前层到下一层
                interLayerCost[layer + 1][node].push_back({ layer, cost }); // 下一层到当前层
            }
        }
    }

    // 最后一层连接回第一层
    for (int node = 0; node < nodes; ++node) {
        if (rand() % 3 == 0) {
            int lastCost = rand() % 2000 + 1000; // 随机权重10-30
            interLayerCost[layers - 1][node].push_back({ 0, lastCost }); // 最后一层到第一层
            interLayerCost[0][node].push_back({ layers - 1, lastCost }); // 第一层到最后一层
        }
    }

    // 起始节点和层
    int startNode = 0;
    int startLayer = 0;

    // 最小代价数组
    vector<vector<int>> minCost(layers, vector<int>(nodes, INF));

    // 运行Dijkstra算法
    auto startTime = chrono::high_resolution_clock::now(); // 开始计时

    dijkstra(startLayer, startNode, graph, interLayerCost, minCost);

    auto endTime = chrono::high_resolution_clock::now(); // 结束计时
    auto duration = chrono::duration_cast<chrono::milliseconds>(endTime - startTime);
    cout << "Total Dijkstra computation time: " << duration.count() << " ms" << endl;

    return 0;
}
```