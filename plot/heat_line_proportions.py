

'''Script that produces heatmap and lineplot of predicted proportions
of gid-cells for each outcome variable'''

#TODO VIEWSADMIN 2018-07-18:
# Make runid an argument with argparse
# Save plots in /storage/runs/current/plots/(heatmap/prolines)/
# Create those dirs if they don't exist
# Read data from DB
# Read the schema and table to plot from argparse
# Read from the database with dbutils.db_to_df()
# See Views/plot/maps/plot_cols.py for example

# RBJ 12-07-2018

import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

# set runid
runid = "r.2018.07.01"

# select outcome variable to plot
outcomes = ["average_select_sb",
            "average_select_ns",
            "average_select_os"]

# select countries to include in lineplot
countries = ["Nigeria", "Sudan", "Rwanda", "Kenya"]

# set up manual color gradient
color_dict1 = {'l1': ["#7F50FCFF", "#7A5CF9FF", "#7569F7FF", "#7175F5FF", "#6C82F2FF",
                      "#678FF0FF", "#639BEEFF", "#5EA8EBFF", "#59B5E9FF", "#55C2E7FF"],
               'l2': ["#55C2E7FF", "#5FC7DDFF", "#6ACCD4FF", "#75D1CBFF", "#7FD6C1FF",
                      "#8ADCB8FF", "#94E1AFFF", "#9FE6A5FF", "#AAEB9CFF", "#B5F193FF"],
               'l3': ["#B5F193FF", "#BBEC8EFF", "#C1E78AFF", "#C7E386FF", "#CDDE82FF",
                      "#D3DA7EFF", "#D9D57AFF", "#DFD176FF", "#E5CC72FF", "#ECC86EFF"],
               'l4': ["#ECC86EFF", "#ECC169FF", "#ECBA65FF", "#EDB360FF", "#EDAC5CFF",
                      "#EDA457FF", "#EE9E53FF", "#EE974EFF", "#EE904AFF", "#EF8946FF"],
               'r1': ["#EF8946FF", "#EE8745FF", "#EE8645FF", "#EE8545FF",
                      "#EE8344FF", "#EE8244FF", "#EE8144FF", "#EE8043FF",
                      "#EE7E43FF", "#EE7D43FF", "#ED7C42FF", "#ED7B42FF",
                      "#ED7942FF", "#ED7841FF", "#ED7741FF", "#ED7641FF",
                      "#ED7440FF", "#ED7340FF", "#ED7240FF", "#ED713FFF",
                      "#EC6F3FFF", "#EC6E3FFF", "#EC6D3EFF", "#EC6C3EFF",
                      "#EC6A3EFF", "#EC693DFF", "#EC683DFF", "#EC673DFF",
                      "#EC653CFF", "#EC643CFF", "#EB633CFF", "#EB623CFF",
                      "#EB603BFF", "#EB5F3BFF", "#EB5E3BFF", "#EB5D3AFF",
                      "#EB5B3AFF", "#EB5A3AFF", "#EB5939FF", "#EB5839FF",
                      "#EA5639FF", "#EA5538FF", "#EA5438FF", "#EA5338FF",
                      "#EA5137FF", "#EA5037FF", "#EA4F37FF", "#EA4E36FF",
                      "#EA4C36FF", "#EA4B36FF", "#E94A35FF", "#E94935FF",
                      "#E94735FF", "#E94634FF", "#E94534FF", "#E94434FF",
                      "#E94233FF", "#E94133FF", "#E94033FF", "#E93F33FF"]}

list_of_lists = [
    color_dict1['l1'],
    color_dict1['l2'],
    color_dict1['l3'],
    color_dict1['l4'],
    color_dict1['r1']]

flattened = [val for sublist in list_of_lists for val in sublist]
mycolorbar1 = LinearSegmentedColormap.from_list('mycolorbar1', flattened)

# @TDOD move to read from DB
# get data (move to standard ensemble_pgm_fcast_test.hdf5)
eval_df = pd.read_csv("/Users/remco/Desktop/eval_df.csv")
eval_df = eval_df.drop('Unnamed: 0', 1)

def compute_proportions(df, var):
    '''computes predicted proportion of gid cells with outcome variable.'''
    df_a = df.groupby(['name', 'month_id'], as_index=False).agg({var: "sum"})
    df_b = df.groupby(['name', 'month_id'], as_index=False).agg({"pg_id": "count"})
    # merge
    df_m = pd.merge(df_a, df_b, on=["name", "month_id"])
    # divide and make proportion columns
    df_m['prop'] = df_m[var] / df_m['pg_id']
    # returns
    return df_m

def plot_heatmap(df, out):
    '''pivots data and plots heatmap.'''
    df_merge = compute_proportions(df, out)

    # take logit and pivot for heatmap
    df_merge['prop_logit'] = np.log(df_merge['prop'] / (1-df_merge['prop']))
    df_matrix = df_merge.pivot(index='name', columns='month_id', values='prop_logit')

    # plot heatmap
    # set size
    plt.figure(figsize=(15, 10))
    # set axes
    ax = sns.heatmap(df_matrix, cmap=mycolorbar1, vmin=np.log(.001/(1-.001)),
                     vmax=np.log(.99/(1-.99)), linewidths=.003)
    ax.set_ylabel('')
    ax.set_xlabel('')
    # colorbar
    cbar = ax.collections[0].colorbar
    cbar.set_ticks([np.log(0.005/(1-0.005)), np.log(0.05/(1-0.05)),
                    np.log(0.40/(1-0.40)), np.log(0.90/(1-0.90)),
                    np.log(0.99/(1-0.99))])
    cbar.set_ticklabels(["0.5%", "5%", "40%", "90%", "99%"])
    # finish and save figure
    plt.title('Country proportions for ' + out + '\n' +
              'Ensemble run: ' + runid, loc='left')
    plt.savefig("heatmap_" + out + ".pdf")

def plot_proplines(df, out, countrylist):
    '''subsets data and plots proportion lines for selected countries.'''
    df_merge = compute_proportions(df, out)
    # subset and initiate plot
    df_line = df_merge[df_merge.name.isin(countrylist)]
    fig, ax = plt.subplots(figsize=(10, 6))
    # plot country lines
    for k, g in df_line.groupby('name'):
        plt.plot(g['month_id'], g['prop'], label=k)
    # finish and save figure
    plt.legend()
    plt.title('Proportion trends for ' + out + '\n' +
              'Ensemble run: ' + runid, loc='left')
    plt.savefig("lineplot_" + out + ".pdf")

for outcome in outcomes:
    plot_heatmap(eval_df, outcome)
    plot_proplines(eval_df, outcome, countries)
